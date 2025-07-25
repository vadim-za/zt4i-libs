const std = @import("std");
const lib = @import("../lib.zig");
const CompareTo = @import("compare_to.zig").CompareTo;
const UpdateNode = @import("update_node.zig").UpdateNode;
const hook_common = @import("../hook_common.zig");

pub fn Tree(
    Node_: type,
    hook_field_name: []const u8,
    compare_to: CompareTo,
    update_node: UpdateNode,
    ownership_tracking: lib.OwnershipTracking,
) type {
    _ = update_node; // autofix
    return struct {
        root: Slot = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

        // Ascribe explicit semantics to ?*Node, so *?*Node becomes *Slot
        const Slot = ?*Node;

        pub const Node = Node_;
        pub const Hook = struct {
            children: [2]Slot = undefined,
            subtree_depth: u32 = undefined,
            ownership_token_storage: OwnershipTraits.ItemTokenStorage = .{},
        };

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
            var node = self.root;

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
        /// be available in some other form. The node should be constructed
        /// latest in the produceNode() call.
        /// ComparableValuePtr is any type compatible to the second argument
        /// of the 'compare_to' functor.
        pub fn insert(self: *@This(), inserter: anytype) InsertionResult {
            _ = self; // autofix
            _ = inserter; // autofix
        }
    };
}
