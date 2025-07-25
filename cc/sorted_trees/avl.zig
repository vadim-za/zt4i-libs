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

        fn traverseBranch(
            self: *const @This(),
            traverser_ptr: anytype,
            branch_root: @TypeOf(traverser_ptr.*).SlotPtr,
        ) @typeInfo(@TypeOf(
            @TypeOf(traverser_ptr.*).arriveAt,
        )).@"fn".return_type.? {
            if (branch_root.*) |node| {
                const hook = self.hookFromOwnedNode(node);

                const subbranch_root: @TypeOf(branch_root) =
                    switch (compareNodeTo(node, traverser_ptr.target())) {
                        .eq => return traverser_ptr.arriveAt(branch_root),
                        .lt => &hook.children[1],
                        .gt => &hook.children[0],
                    };

                const result =
                    self.traverseBranch(traverser_ptr, subbranch_root);

                traverser_ptr.retrace(subbranch_root);
                return result;
            } else {
                return traverser_ptr.arriveAt(branch_root);
            }
        }

        pub fn find(
            self: *const @This(),
            comparable_value_ptr: anytype,
        ) ?*Node {
            const ComparableValuePtr = @TypeOf(comparable_value_ptr);

            const traverser: struct {
                comparable_value_ptr: ComparableValuePtr,
                const SlotPtr = *const Slot;

                fn target(traverser_self: @This()) ComparableValuePtr {
                    return traverser_self.comparable_value_ptr;
                }
                fn arriveAt(_: @This(), slot: SlotPtr) ?*Node {
                    return slot.*;
                }
                fn retrace(_: @This(), _: SlotPtr) void {}
            } = .{ .comparable_value_ptr = comparable_value_ptr };

            return self.traverseBranch(&traverser, &self.root);
        }
    };
}
