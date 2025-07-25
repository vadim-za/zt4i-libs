const std = @import("std");
const lib = @import("../lib.zig");
const CompareTo = @import("compare_to.zig").CompareTo;
const hook_common = @import("../hook_common.zig");

pub fn Tree(
    Node_: type,
    hook_field_name: []const u8,
    compare_to: CompareTo,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        root_: Slot = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

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

        const HookCommon = hook_common.For(@This(), hook_field_name);
        pub const hookFromFreeNode = HookCommon.hookFromFreeNode;
        pub const hookFromOwnedNode = HookCommon.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = HookCommon.hookFromOwnedConstNode;

        fn compareNodeTo(
            node: *Node,
            comparable_value_ptr: anytype,
        ) std.math.Order {
            return compare_to.call(node, comparable_value_ptr);
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

        /// 'inserter' can be a small struct or a pointer to one and must
        /// provide the following methods:
        ///     fn inserter.key() ComparableValuePtr;
        ///     fn inserter.produceNode() *Node;
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
            retracer: anytype,
        ) InsertionResult {
            return self.insertUnder(&self.root_, inserter, retracer);
        }

        /// This function may be used only if 'compare_to' is capable
        /// of comparing to a '*Node' value.
        pub fn insertNode(
            self: *@This(),
            node: *Node,
            retracer: anytype,
        ) InsertionResult {
            return self.insert(
                struct {
                    node: *Node,

                    fn key(ins: *const @This()) *Node {
                        return ins.node;
                    }
                    fn produceNode(ins: *const @This()) *Node {
                        return ins.node;
                    }
                }{ .node = node },
                retracer,
            );
        }

        fn insertUnder(
            self: *@This(),
            slot: *Slot,
            inserter: anytype,
            retracer: anytype,
        ) InsertionResult {
            if (slot.*) |node| {
                const hook = self.hookFromOwnedNode(node);

                const subslot = switch (compareNodeTo(node, inserter.key())) {
                    .eq => return .{ .success = false, .node = node },
                    .lt => &hook.children[1],
                    .gt => &hook.children[0],
                };

                const result = self.insertUnder(subslot, inserter, retracer);
                if (result.success)
                    self.rebalanceSlot(slot, retracer);
                return result;
            } else {
                const node = inserter.produceNode();
                const hook = self.hookFromFreeNode(node);
                hook.* = .{
                    .children = .{ null, null },
                    .subtree_depth = undefined,
                    .ownership_token_storage = .from(self),
                };
                self.updateNodeCachedData(node, retracer);
                slot.* = node;
                return .{ .success = true, .node = node };
            }
        }

        fn rebalanceSlot(self: *@This(), slot: *Slot, retracer: anytype) void {
            const node = slot.*.?;
            const hook = self.hookFromOwnedNode(node);
            const balance = self.balanceOf(hook);

            if (@abs(balance) > 1) {
                std.debug.assert(@abs(balance) == 2);
                self.rebalanceSlotFrom(
                    if (balance < 0) 0 else 1,
                    slot,
                    retracer,
                );
                std.debug.assert(@abs(self.balanceOf(hook)) <= 1);
            } else {
                self.updateNodeCachedData(node, retracer);
            }
        }

        fn rebalanceSlotFrom(
            self: *@This(),
            from: u1,
            slot: *Slot,
            retracer: anytype,
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
                self.rotateSlot(from_slot, ~from, retracer);
            self.rotateSlot(slot, from, retracer);
        }

        fn rotateSlot(
            self: *@This(),
            slot: *Slot,
            from: u1,
            retracer: anytype,
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

            self.updateNodeCachedData(node, retracer);
            self.updateNodeCachedData(from_node, retracer);
        }

        fn updateNodeCachedData(
            self: *@This(),
            node: *Node,
            retracer: anytype,
        ) void {
            const hook = self.hookFromOwnedNode(node);

            hook.subtree_depth = @max(
                self.cachedSubtreeDepthOf(hook.children[0]),
                self.cachedSubtreeDepthOf(hook.children[1]),
            ) + 1;

            self.retrace(node, retracer);
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

        fn retrace(self: *const @This(), node: *Node, retracer: anytype) void {
            if (@TypeOf(retracer) == void)
                return;
            _ = self;
            _ = node;
            @compileError("Retracing not supported yet");
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
