const std = @import("std");
const lib = @import("../lib.zig");
const CompareTo = @import("compare_to.zig").CompareTo;
const hook_common = @import("../hook_common.zig");
const callbacks = @import("callbacks.zig");

pub fn Tree(
    Node_: type,
    config_: lib.trees.Config,
) type {
    return struct {
        root_: Slot = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        pub const config = config_;
        const OwnershipTraits = config.ownership_tracking.TraitsFor(@This());

        // Ascribe explicit semantics to ?*Node, so *?*Node becomes *Slot
        const Slot = ?*Node;

        pub const Node = Node_;
        pub const Hook = struct {
            children: [2]Slot = undefined,
            subtree_depth: i32 = undefined,
            ownership_token_storage: OwnershipTraits.ItemTokenStorage = .{},
        };

        pub fn deinit(self: *const @This()) void {
            if (comptime !OwnershipTraits.can_discard_content)
                std.debug.assert(!self.hasContent());
        }

        pub const setOwnershipToken = OwnershipTraits.setContainerToken;

        const HookCommon = hook_common.With(@This(), config.hook_field);
        pub const hookFromFreeNode = HookCommon.hookFromFreeNode;
        pub const hookFromOwnedNode = HookCommon.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = HookCommon.hookFromOwnedConstNode;

        fn compareNodeTo(
            node: *Node,
            comparable_value_ptr: anytype,
        ) std.math.Order {
            return config.compare_to.call(node, comparable_value_ptr);
        }

        pub fn find(
            self: *const @This(),
            comparable_value_ptr: anytype,
        ) ?*Node {
            var node = self.root_;

            return while (node) |n| {
                const hook = self.hookFromOwnedNode(n);

                node = switch (compareNodeTo(n, comparable_value_ptr)) {
                    .eq => break n,
                    .lt => hook.children[1],
                    .gt => hook.children[0],
                };
            } else null;
        }

        pub const InsertionResult = struct {
            /// false if an equal node has been found, otherwise true
            success: bool,
            /// if(success) inserted_node else found_node
            node: *Node,
        };

        fn InsertionCallResult(Inserter: type) type {
            const ActualInserter = switch (@typeInfo(Inserter)) {
                .pointer => |p| p.child,
                else => Inserter,
            };

            const ProduceNode = @TypeOf(ActualInserter.produceNode);
            const ProduceNodeResult =
                @typeInfo(ProduceNode).@"fn".return_type.?;

            var info = @typeInfo(ProduceNodeResult);
            const u = &info.error_union;
            u.payload = InsertionResult;
            return @Type(info);
        }

        /// 'inserter' can be a small struct or a pointer to one and must
        /// provide the following methods:
        ///     fn inserter.key() ComparableValuePtr;
        ///     fn inserter.produceNode() !*Node;
        /// The rationale behind the idea of the 'inserter' is that we do not
        /// have to construct the tree node object until we know that we are
        /// really inserting it, since there can already be an equal node in
        /// the tree, in which case we won't insert the new node. During that
        /// time the respective information (including the node's "key") might
        /// be available in some other form.
        /// The node should be constructed latest in the produceNode() call.
        /// The "key" of the constructed node must be semantically identical
        /// to the one returned by inserter.key().
        /// ComparableValuePtr is any type compatible to the second argument
        /// of the 'compare_to' functor.
        pub fn insert(
            self: *@This(),
            inserter: anytype,
            retracer_callback: anytype,
        ) !InsertionResult {
            return self.insertUnder(
                &self.root_,
                inserter,
                &callbacks.parseSpec(&retracer_callback, "retracer"),
            );
        }

        /// This function may be used only if 'compare_to' is capable
        /// of comparing to a '*Node' value.
        pub fn insertNode(
            self: *@This(),
            node: *Node,
            retracer_callback: anytype,
        ) InsertionResult {
            return self.insert(
                struct {
                    node: *Node,

                    fn key(ins: *const @This()) *const Node {
                        return ins.node;
                    }
                    fn produceNode(ins: *const @This()) !*Node {
                        return ins.node;
                    }
                }{ .node = node },
                retracer_callback,
            ) catch |err|
                switch (err) {};
            // an empty switch checks at compile time that the error set
            // is empty
        }

        fn insertUnder(
            self: *@This(),
            slot: *Slot,
            inserter: anytype,
            parsed_retracer_ptr: anytype,
        ) InsertionCallResult(@TypeOf(inserter)) {
            const Result = InsertionCallResult(@TypeOf(inserter));
            const err_result = @typeInfo(Result) == .error_union;

            if (slot.*) |node| {
                const hook = self.hookFromOwnedNode(node);

                const subslot = switch (compareNodeTo(node, inserter.key())) {
                    .eq => return .{ .success = false, .node = node },
                    .lt => &hook.children[1],
                    .gt => &hook.children[0],
                };

                const call_result = self.insertUnder(
                    subslot,
                    inserter,
                    parsed_retracer_ptr,
                );
                const result = if (err_result)
                    try call_result
                else
                    call_result;

                if (result.success)
                    self.rebalanceSlot(slot, parsed_retracer_ptr);
                return result;
            } else {
                const node = if (err_result)
                    try inserter.produceNode()
                else
                    inserter.produceNode();

                const hook = self.hookFromFreeNode(node);
                hook.* = .{
                    .children = .{ null, null },
                    .subtree_depth = undefined,
                    .ownership_token_storage = .from(self),
                };
                self.updateNodeCachedData(node, parsed_retracer_ptr);
                slot.* = node;

                return .{ .success = true, .node = node };
            }
        }

        // Returns the removed node or null if node not found
        pub fn remove(
            self: *@This(),
            comparable_value_ptr: anytype,
            retracer_callback: anytype,
        ) ?*Node {
            return self.removeUnder(
                &self.root_,
                comparable_value_ptr,
                &callbacks.parseSpec(&retracer_callback, "retracer"),
            );
        }

        pub fn removeUnder(
            self: *@This(),
            slot: *Slot,
            comparable_value_ptr: anytype,
            parsed_retracer_ptr: anytype,
        ) ?*Node {
            const node = slot.* orelse return null;
            const hook = self.hookFromOwnedNode(node);

            const subslot =
                switch (compareNodeTo(node, comparable_value_ptr)) {
                    .eq => return self.removeAt(slot, parsed_retracer_ptr),
                    .lt => &hook.children[1],
                    .gt => &hook.children[0],
                };

            const result = self.removeUnder(
                subslot,
                comparable_value_ptr,
                parsed_retracer_ptr,
            );

            if (result != null)
                self.rebalanceSlot(slot, parsed_retracer_ptr);
            return result;
        }

        fn removeAt(
            self: *@This(),
            slot: *Slot,
            parsed_retracer_ptr: anytype,
        ) ?*Node {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);

            if (hook.subtree_depth > 1) {
                const balance = self.balanceOf(hook);
                const replacement_branch: u1 = if (balance > 0) 1 else 0;

                const replacement_node = self.retrieveReplacementNode(
                    &hook.children[replacement_branch],
                    ~replacement_branch,
                    parsed_retracer_ptr,
                );

                slot.* = replacement_node;
                const replacement_hook =
                    self.hookFromOwnedNode(replacement_node);
                replacement_hook.children = hook.children;

                self.rebalanceSlot(slot, parsed_retracer_ptr);
            } else {
                slot.* = null;
            }

            hook.* = .{};
            return node;
        }

        fn retrieveReplacementNode(
            self: *@This(),
            slot: *Slot,
            branch: u1,
            parsed_retracer_ptr: anytype,
        ) *Node {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);
            const child_slot = &hook.children[branch];

            if (child_slot.* != null) {
                const replacement_node = self.retrieveReplacementNode(
                    child_slot,
                    branch,
                    parsed_retracer_ptr,
                );

                self.rebalanceSlot(slot, parsed_retracer_ptr);
                return replacement_node;
            } else {
                const other_child = hook.children[~branch];

                slot.* = other_child;
                return node;
            }
        }

        pub fn removeAll(self: *@This(), discarder: anytype) void {
            const parsed_discarder =
                callbacks.parseSpec(&discarder, "discarder");

            const can_discard_content = @TypeOf(parsed_discarder) == void and
                OwnershipTraits.can_discard_content;

            if (comptime !can_discard_content)
                self.releaseAllUnder(self.root_, &parsed_discarder);

            self.root_ = null;
        }

        fn releaseAllUnder(
            self: *@This(),
            node: ?*Node,
            parsed_discarder_ptr: anytype,
        ) void {
            const n = node orelse return;
            const hook = self.hookFromOwnedNode(n);
            self.releaseAllUnder(hook.children[0], parsed_discarder_ptr);
            self.releaseAllUnder(hook.children[1], parsed_discarder_ptr);
            hook.* = .{};

            if (@TypeOf(parsed_discarder_ptr.*) != void)
                callbacks.call(
                    parsed_discarder_ptr,
                    "discard",
                    .{n},
                    void,
                );
        }

        fn rebalanceSlot(
            self: *@This(),
            slot: *Slot,
            parsed_retracer_ptr: anytype,
        ) void {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);
            const balance = self.balanceOf(hook);

            if (@abs(balance) > 1) {
                std.debug.assert(@abs(balance) == 2);
                self.rebalanceSlotFrom(
                    if (balance < 0) 0 else 1,
                    slot,
                    parsed_retracer_ptr,
                );
                std.debug.assert(@abs(self.balanceOf(hook)) <= 1);
            } else {
                self.updateNodeCachedData(node, parsed_retracer_ptr);
            }
        }

        fn rebalanceSlotFrom(
            self: *@This(),
            from: u1,
            slot: *Slot,
            parsed_retracer_ptr: anytype,
        ) void {
            const hook = self.hookFromOwnedNode(slot.*.?);
            const from_slot = &hook.children[from];
            const from_hook = self.hookFromOwnedNode(from_slot.*.?);
            const from_balance = self.balanceFrom(from, from_hook);

            // if (from_balance <= 0)
            // ----------------------
            //     slot.*                     from
            //     /    \                    /    \
            //   (A)   from       =>      slot.*  (B)
            //        /    \              /    \
            //      (C)    (B)          (A)   (C)
            //
            // if (from_balance > 0)
            // ---------------------
            //     slot.*                slot.*                     C
            //     /    \                /    \                   /   \
            //   (A)   from            (A)     C             slot.*    from
            //        /    \     =>          /   \      =>   /   \     /  \
            //       C     (B)             (E)  from       (A)   (E) (D)  (B)
            //      / \                        /    \
            //    (E) (D)                    (D)    (B)

            if (from_balance > 0)
                self.rotateSlot(from_slot, ~from, parsed_retracer_ptr);
            self.rotateSlot(slot, from, parsed_retracer_ptr);
        }

        fn rotateSlot(
            self: *@This(),
            slot: *Slot,
            from: u1,
            parsed_retracer_ptr: anytype,
        ) void {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);

            const from_node = hook.children[from].?;
            const from_hook = self.hookFromOwnedNode(from_node);

            const from_to_node = from_hook.children[~from]; // optional

            //      node                      from
            //     /    \                    /    \
            //   (A)   from       =>       node   (B)
            //        /    \              /    \
            //   (from_to) (B)          (A)  (from_to)
            slot.* = from_node;
            from_hook.children[~from] = node;
            hook.children[from] = from_to_node;

            self.updateNodeCachedData(node, parsed_retracer_ptr);
            self.updateNodeCachedData(from_node, parsed_retracer_ptr);
        }

        fn updateNodeCachedData(
            self: *@This(),
            node: *Node,
            parsed_retracer_ptr: anytype,
        ) void {
            const hook = self.hookFromOwnedNode(node);

            hook.subtree_depth = @max(
                self.cachedSubtreeDepthOf(hook.children[0]),
                self.cachedSubtreeDepthOf(hook.children[1]),
            ) + 1;

            if (@TypeOf(parsed_retracer_ptr.*) != void)
                callbacks.call(
                    parsed_retracer_ptr,
                    "retrace",
                    .{ node, self.children(node) },
                    void,
                );
        }

        fn cachedSubtreeDepthOf(self: *const @This(), slot: Slot) i32 {
            return if (slot) |node|
                self.hookFromOwnedNode(node).subtree_depth
            else
                0;
        }

        // depth_to - depth_from
        fn balanceFrom(
            self: *const @This(),
            from: u1,
            hook: *Hook,
        ) i32 {
            const depth_from = self.cachedSubtreeDepthOf(hook.children[from]);
            const depth_to = self.cachedSubtreeDepthOf(hook.children[~from]);
            return depth_to - depth_from;
        }

        fn balanceOf(self: *const @This(), hook: *Hook) i32 {
            return self.balanceFrom(0, hook);
        }

        pub fn hasContent(self: *const @This()) bool {
            return self.root_ != null;
        }

        pub fn root(self: *const @This()) ?*Node {
            return self.root_;
        }

        pub fn children(
            self: *const @This(),
            node: *const Node,
        ) *const [2]?*Node {
            const hook = self.hookFromOwnedConstNode(node);
            return &hook.children;
        }
    };
}

pub fn verifyTree(tree_ptr: anytype) !void {
    _ = try verifySubtree(tree_ptr, tree_ptr.root());
}

fn verifySubtree(tree_ptr: anytype, node_ptr: anytype) !i32 {
    const node = node_ptr orelse
        return 0;

    const hook = tree_ptr.hookFromOwnedConstNode(node);

    // verify may be only called on trees which support comparison to nodes
    const Tree_ = @TypeOf(tree_ptr.*);
    if (hook.children[0]) |child|
        std.debug.assert(Tree_.compareNodeTo(node, child) == .gt);
    if (hook.children[1]) |child|
        std.debug.assert(Tree_.compareNodeTo(node, child) == .lt);

    const depth = @max(
        try verifySubtree(tree_ptr, hook.children[0]),
        try verifySubtree(tree_ptr, hook.children[1]),
    ) + 1;
    std.debug.assert(depth == hook.subtree_depth);

    return depth;
}
