const std = @import("std");
const lib = @import("../../lib.zig");
const hook_common = @import("../../hook_common.zig");

/// This single-linked list stores the pointer to the first element.
/// The termination is indicated by the next pointer set to null.
pub fn List(
    Node_: type,
    hook_field_name: []const u8,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

        pub const Node = Node_;
        pub const Hook = struct {
            next: ?*Node = undefined,
            ownership_token_storage: OwnershipTraits.ItemTokenStorage = .{},
        };

        pub fn init(self: *@This()) void {
            self.* = .{};
        }

        pub fn deinit(self: *const @This()) void {
            if (comptime !OwnershipTraits.can_discard_content)
                std.debug.assert(!self.hasContent());
        }

        pub const setOwnershipToken = OwnershipTraits.setContainerToken;

        const HookCommon = hook_common.For(@This(), hook_field_name);
        pub const hookFromFreeNode = HookCommon.hookFromFreeNode;
        pub const hookFromOwnedNode = HookCommon.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = HookCommon.hookFromOwnedConstNode;

        // -------------------- insertion/removal

        pub const InsertionPos = union(enum) {
            first: void,
            after_: *Node,

            pub inline fn after(node: ?*Node) @This() {
                return if (node) |n| .{ .after_ = n } else .first;
            }
        };

        pub inline fn insert(self: *@This(), where: InsertionPos, node: *Node) void {
            switch (where) {
                .first => self.insertFirst(node),
                .after_ => |prev_node| self.insertAfter(prev_node, node),
            }
        }

        pub fn insertFirst(self: *@This(), node: *Node) void {
            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .next = self.first_,
                .ownership_token_storage = .from(self),
            };

            self.first_ = node;
        }

        pub fn insertAfter(
            self: *@This(),
            prev_node: *Node,
            node: *Node,
        ) void {
            const hook = self.hookFromFreeNode(node);
            const prev_hook = self.hookFromOwnedNode(prev_node);

            hook.* = .{
                .next = prev_hook.next,
                .ownership_token_storage = .from(self),
            };

            prev_hook.next = node;
        }

        pub fn removeFirst(self: *@This()) void {
            const hook = self.hookFromOwnedNode(self.first_.?);
            self.first_ = hook.next;
            hook.* = .{};
        }

        // -------------------- standard inspection

        pub fn first(self: *const @This()) ?*Node {
            return self.first_;
        }

        pub fn next(self: *const @This(), node: *const Node) ?*Node {
            const hook = self.hookFromOwnedConstNode(node);
            return hook.next;
        }

        pub fn hasContent(self: *const @This()) bool {
            return self.first_ != null;
        }

        pub fn popFirst(self: *@This()) ?*Node {
            if (self.first()) |node| {
                self.removeFirst();
                return node;
            }
            return null;
        }

        pub fn removeAll(self: *@This()) void {
            while (self.first() != null)
                self.removeFirst();
        }
    };
}
