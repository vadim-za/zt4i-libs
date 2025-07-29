const std = @import("std");
const lib = @import("../lib.zig");
const CompareTo = @import("compare_to.zig").CompareTo;
const hook_common = @import("../hook_common.zig");
const callbacks_support = @import("callbacks.zig");

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
            if (Inserter != *Node) {
                const CallbackResult =
                    callbacks_support.ResultOf(Inserter, "produceNode");

                var info = @typeInfo(CallbackResult);
                switch (info) {
                    .error_union => |*u| {
                        comptime std.debug.assert(u.payload == *Node);
                        u.payload = InsertionResult;
                        return @Type(info);
                    },
                    else => {},
                }
            }

            return error{}!InsertionResult;
        }

        /// This function is a quick shortcut and may be used only if
        /// 'compare_to' is capable of comparing to a '*Node' value,
        /// otherwise you need to use the insert() function (which
        /// might be an overall good idea).
        pub fn insertNode(
            self: *@This(),
            node: *Node,
            callbacks: anytype, // [.retracer]
        ) InsertionResult {
            comptime callbacks_support.accept(.{
                .retracer = {},
            }, @TypeOf(callbacks));

            const Callbacks = @TypeOf(callbacks);

            return self.insert(
                node,
                if (@hasField(Callbacks, "retracer")) .{
                    .inserter = node,
                    .retracer = callbacks.retracer,
                } else .{ .inserter = node },
            ) catch |err|
                switch (err) {};
            // an empty switch checks at compile time that the error set
            // is empty
        }

        /// 'comparable_value_ptr' must be a pointer to the inserted
        /// node's key value or to a value which compares in a way fully
        /// identical to how the node's key compares.
        ///
        /// The 'inserter' callback is required and should be one of the
        /// following:
        /// 1. A small struct object of a type similar to the following one:
        ///     struct {
        ///         some struct field declarations ...
        ///         ......
        ///         pub fn produceNode(self: *const @This()) !*Node {
        ///             .....
        ///         }
        ///     }
        /// 2. A tuple with the first argument being a callable (a function
        /// or a pointer thereto), and the following arguments containing the
        /// leading arguments of the callable. The callable should return an
        /// error union with *Node, like the produceNode() method above.
        /// 3. A '*Node' value.
        ///
        /// See library documentation for further details.
        pub fn insert(
            self: *@This(),
            comparable_value_ptr: anytype,
            callbacks: anytype, // .inserter, [.retracer]
        ) !InsertionResult {
            comptime callbacks_support.accept(.{
                .inserter = {},
                .retracer = {},
            }, @TypeOf(callbacks));

            // Work around #19483
            const Callbacks = @TypeOf(callbacks);
            const inserter = callbacks.inserter;
            const retracer = if (@hasField(Callbacks, "retracer"))
                callbacks.retracer;

            return self.insertUnder(
                &self.root_,
                comparable_value_ptr,
                &inserter,
                &retracer,
            );
        }

        fn insertUnder(
            self: *@This(),
            slot: *Slot,
            comparable_value_ptr: anytype,
            inserter_ptr: anytype,
            opt_retracer_ptr: anytype,
        ) InsertionCallResult(@TypeOf(inserter_ptr.*)) {
            if (slot.*) |node| {
                const hook = self.hookFromOwnedNode(node);

                const subslot =
                    switch (compareNodeTo(node, comparable_value_ptr)) {
                        .eq => return .{ .success = false, .node = node },
                        .lt => &hook.children[1],
                        .gt => &hook.children[0],
                    };

                const result = try self.insertUnder(
                    subslot,
                    comparable_value_ptr,
                    inserter_ptr,
                    opt_retracer_ptr,
                );

                if (result.success)
                    self.rebalanceSlot(slot, opt_retracer_ptr);
                return result;
            } else {
                const node = if (@TypeOf(inserter_ptr.*) == *Node)
                    inserter_ptr.*
                else
                    try callbacks_support.call(
                        inserter_ptr,
                        "produceNode",
                        .{},
                    );

                const hook = self.hookFromFreeNode(node);
                hook.* = .{
                    .children = .{ null, null },
                    .subtree_depth = undefined,
                    .ownership_token_storage = .from(self),
                };
                self.updateNodeCachedData(node, opt_retracer_ptr);
                slot.* = node;

                return .{ .success = true, .node = node };
            }
        }

        // Returns the removed node or null if node not found
        pub fn remove(
            self: *@This(),
            comparable_value_ptr: anytype,
            callbacks: anytype, // [.retracer]
        ) ?*Node {
            comptime callbacks_support.accept(.{
                .retracer = {},
            }, @TypeOf(callbacks));

            // Work around #19483
            const Callbacks = @TypeOf(callbacks);
            const retracer = if (@hasField(Callbacks, "retracer"))
                callbacks.retracer;

            return self.removeUnder(
                &self.root_,
                comparable_value_ptr,
                &retracer,
            );
        }

        fn removeUnder(
            self: *@This(),
            slot: *Slot,
            comparable_value_ptr: anytype,
            opt_retracer_ptr: anytype,
        ) ?*Node {
            const node = slot.* orelse return null;
            const hook = self.hookFromOwnedNode(node);

            const subslot =
                switch (compareNodeTo(node, comparable_value_ptr)) {
                    .eq => return self.removeAt(slot, opt_retracer_ptr),
                    .lt => &hook.children[1],
                    .gt => &hook.children[0],
                };

            const result = self.removeUnder(
                subslot,
                comparable_value_ptr,
                opt_retracer_ptr,
            );

            if (result != null)
                self.rebalanceSlot(slot, opt_retracer_ptr);
            return result;
        }

        fn removeAt(
            self: *@This(),
            slot: *Slot,
            opt_retracer_ptr: anytype,
        ) ?*Node {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);

            if (hook.subtree_depth > 1) {
                const balance = self.balanceOf(hook);
                const replacement_branch: u1 = if (balance > 0) 1 else 0;

                const replacement_node = self.retrieveReplacementNode(
                    &hook.children[replacement_branch],
                    ~replacement_branch,
                    opt_retracer_ptr,
                );

                slot.* = replacement_node;
                const replacement_hook =
                    self.hookFromOwnedNode(replacement_node);
                replacement_hook.children = hook.children;

                self.rebalanceSlot(slot, opt_retracer_ptr);
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
            opt_retracer_ptr: anytype,
        ) *Node {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);
            const child_slot = &hook.children[branch];

            if (child_slot.* != null) {
                const replacement_node = self.retrieveReplacementNode(
                    child_slot,
                    branch,
                    opt_retracer_ptr,
                );

                self.rebalanceSlot(slot, opt_retracer_ptr);
                return replacement_node;
            } else {
                const other_child = hook.children[~branch];

                slot.* = other_child;
                return node;
            }
        }

        pub fn removeAll(
            self: *@This(),
            callbacks: anytype, // [.discarder]
        ) void {
            comptime callbacks_support.accept(.{
                .discarder = {},
            }, @TypeOf(callbacks));

            // Work around #19483
            const Callbacks = @TypeOf(callbacks);
            const discarder = if (@hasField(Callbacks, "discarder"))
                callbacks.discarder;

            const can_discard_content = @TypeOf(discarder) == void and
                OwnershipTraits.can_discard_content;

            if (comptime !can_discard_content)
                self.releaseAllUnder(self.root_, &discarder);

            self.root_ = null;
        }

        fn releaseAllUnder(
            self: *@This(),
            node: ?*Node,
            opt_discarder_ptr: anytype,
        ) void {
            const n = node orelse return;
            const hook = self.hookFromOwnedNode(n);
            self.releaseAllUnder(hook.children[0], opt_discarder_ptr);
            self.releaseAllUnder(hook.children[1], opt_discarder_ptr);
            hook.* = .{};

            if (@TypeOf(opt_discarder_ptr.*) != void)
                callbacks_support.call(
                    opt_discarder_ptr,
                    "discard",
                    .{n},
                );
        }

        fn rebalanceSlot(
            self: *@This(),
            slot: *Slot,
            opt_retracer_ptr: anytype,
        ) void {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);
            const balance = self.balanceOf(hook);

            if (@abs(balance) > 1) {
                std.debug.assert(@abs(balance) == 2);
                self.rebalanceSlotFrom(
                    if (balance < 0) 0 else 1,
                    slot,
                    opt_retracer_ptr,
                );
                std.debug.assert(@abs(self.balanceOf(hook)) <= 1);
            } else {
                self.updateNodeCachedData(node, opt_retracer_ptr);
            }
        }

        fn rebalanceSlotFrom(
            self: *@This(),
            from: u1,
            slot: *Slot,
            opt_retracer_ptr: anytype,
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
                self.rotateSlot(from_slot, ~from, opt_retracer_ptr);
            self.rotateSlot(slot, from, opt_retracer_ptr);
        }

        fn rotateSlot(
            self: *@This(),
            slot: *Slot,
            from: u1,
            opt_retracer_ptr: anytype,
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

            self.updateNodeCachedData(node, opt_retracer_ptr);
            self.updateNodeCachedData(from_node, opt_retracer_ptr);
        }

        fn updateNodeCachedData(
            self: *@This(),
            node: *Node,
            opt_retracer_ptr: anytype,
        ) void {
            const hook = self.hookFromOwnedNode(node);

            hook.subtree_depth = @max(
                self.cachedSubtreeDepthOf(hook.children[0]),
                self.cachedSubtreeDepthOf(hook.children[1]),
            ) + 1;

            if (@TypeOf(opt_retracer_ptr.*) != void)
                callbacks_support.call(
                    opt_retracer_ptr,
                    "retrace",
                    .{ node, self.children(node) },
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
