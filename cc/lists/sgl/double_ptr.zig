const std = @import("std");
const lib = @import("../../lib.zig");
const hook_common = @import("../../hook_common.zig");

/// This single-linked list stores the pointers to the first and last elements.
/// The termination is indicated by the next pointer set to null.
pub fn List(
    Node_: type,
    config_: lib.lists.Config,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        last_: ?*Node = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        pub const config = config_;
        const OwnershipTraits = config.ownership_tracking.TraitsFor(@This());

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

        const HookCommon = hook_common.With(@This(), config.hook_field);
        pub const hookFromFreeNode = HookCommon.hookFromFreeNode;
        pub const hookFromOwnedNode = HookCommon.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = HookCommon.hookFromOwnedConstNode;

        // -------------------- insertion/removal

        pub const InsertionPos = union(enum) {
            first: void,
            last: void,
            after_: *Node,

            pub inline fn after(node: ?*Node) @This() {
                return if (node) |n| .{ .after_ = n } else .first;
            }
        };

        pub inline fn insert(self: *@This(), where: InsertionPos, node: *Node) void {
            switch (where) {
                .first => self.insertFirst(node),
                .last => self.insertLast(node),
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

        pub fn insertLast(self: *@This(), node: *Node) void {
            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .next = null,
                .ownership_token_storage = .from(self),
            };

            if (self.last_) |last_node| {
                const last_hook = self.hookFromOwnedNode(last_node);
                std.debug.assert(last_hook.next == null);
                last_hook.next = node;
            } else {
                self.first_ = node;
            }

            self.last_ = node;
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

            if (prev_node == self.last_)
                self.last_ = node;
        }

        pub fn removeFirst(self: *@This()) void {
            const node = self.first_.?;
            const hook = self.hookFromOwnedNode(node);

            self.first_ = hook.next;
            if (self.last_ == node)
                self.last_ = null;

            hook.* = .{};
        }

        // -------------------- standard inspection

        pub fn first(self: *const @This()) ?*Node {
            return self.first_;
        }

        pub fn last(self: *const @This()) ?*Node {
            return self.last_;
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
