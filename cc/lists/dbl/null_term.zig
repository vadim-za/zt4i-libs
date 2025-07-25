const std = @import("std");
const lib = @import("../../lib.zig");
const hook_common = @import("../hook_common.zig");
const dbl_common = @import("common.zig");
const insertion = @import("insertion.zig");

/// This double-linked list stores the pointers to the first and last elements.
/// The termination is indicated by prev/next pointers set to null.
pub fn List(
    Node_: type,
    hook_field_name: []const u8,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        last_: ?*Node = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        const Self = @This();

        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

        pub const Node = Node_;
        pub const Hook = struct {
            next: ?*Node = undefined,
            prev: ?*Node = undefined,
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

        pub const InsertionPos = insertion.InsertionPos(Node);

        pub inline fn insert(self: *@This(), where: InsertionPos, node: *Node) void {
            switch (where) {
                .first => self.insertFirst(node),
                .last => self.insertLast(node),
                .before_ => |next_node| self.insertBefore(next_node, node),
                .after_ => |prev_node| self.insertAfter(prev_node, node),
            }
        }

        pub fn insertFirst(self: *@This(), node: *Node) void {
            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .prev = null,
                .next = self.first_,
                .ownership_token_storage = .from(self),
            };

            if (self.first_) |first_node|
                self.hookFromOwnedNode(first_node).prev = node
            else
                self.last_ = node;

            self.first_ = node;
        }

        pub fn insertLast(self: *@This(), node: *Node) void {
            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .prev = self.last_,
                .next = null,
                .ownership_token_storage = .from(self),
            };

            if (self.last_) |last_node|
                self.hookFromOwnedNode(last_node).next = node
            else
                self.first_ = node;

            self.last_ = node;
        }

        pub fn insertBefore(
            self: *@This(),
            next_node: *Node,
            node: *Node,
        ) void {
            const hook = self.hookFromFreeNode(node);
            const next_hook = self.hookFromOwnedNode(next_node);

            const prev_node = if (next_hook.prev) |prev_node| prev: {
                std.debug.assert(next_node != self.first_);
                self.hookFromOwnedNode(prev_node).next = node;
                break :prev prev_node;
            } else prev: {
                std.debug.assert(next_node == self.first_);
                self.first_ = node;
                break :prev null;
            };

            next_hook.prev = node;

            hook.* = .{
                .prev = prev_node,
                .next = next_node,
                .ownership_token_storage = .from(self),
            };
        }

        pub fn insertAfter(
            self: *@This(),
            prev_node: *Node,
            node: *Node,
        ) void {
            const hook = self.hookFromFreeNode(node);
            const prev_hook = self.hookFromOwnedNode(prev_node);

            const next_node = if (prev_hook.next) |next_node| next: {
                std.debug.assert(prev_node != self.last_);
                self.hookFromOwnedNode(next_node).prev = node;
                break :next next_node;
            } else next: {
                std.debug.assert(prev_node == self.last_);
                self.last_ = node;
                break :next null;
            };

            prev_hook.next = node;

            hook.* = .{
                .prev = prev_node,
                .next = next_node,
                .ownership_token_storage = .from(self),
            };
        }

        pub fn remove(self: *@This(), node: *Node) void {
            const hook = self.hookFromOwnedNode(node);

            if (hook.prev) |prev_node| {
                std.debug.assert(node != self.first_);
                self.hookFromOwnedNode(prev_node).next = hook.next;
            } else {
                std.debug.assert(node == self.first_);
                self.first_ = hook.next;
            }

            if (hook.next) |next_node| {
                std.debug.assert(node != self.last_);
                self.hookFromOwnedNode(next_node).prev = hook.prev;
            } else {
                std.debug.assert(node == self.last_);
                self.last_ = hook.prev;
            }

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

        pub fn prev(self: *const @This(), node: *const Node) ?*Node {
            const hook = self.hookFromOwnedConstNode(node);
            return hook.prev;
        }

        pub fn hasContent(self: *const @This()) bool {
            return self.first_ != null;
        }

        const DblCommon = dbl_common.For(@This());
        pub const popFirst = DblCommon.popFirst;
        pub const popLast = DblCommon.popLast;
        pub const removeAll = DblCommon.removeAll;
    };
}
