const std = @import("std");
const lib = @import("../../lib.zig");
const CommonMethods = @import("../common.zig").Methods;
const insertion = @import("insertion.zig");

/// This double-linked list stores only the pointer to the first element,
/// thereby saving memory at the cost of a bit more involved list manipulation
/// and inspection code.
pub fn List(
    Payload: type,
    layout: lib.Layout,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage = .{},

        /// This field may be accessed publicly to set the internal
        /// state of a non-empty layout. The layout type still must
        /// be default-initializable with .{} even if it's non-empty.
        layout: Layout = .{},

        const Self = @This();

        pub const Layout = layout.make(@This(), Payload);
        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

        pub const Node = Layout.Node;
        pub const Hook = struct {
            next: *Node = undefined,
            prev: *Node = undefined,
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

        const Methods = CommonMethods(@This());
        pub const hookFromFreeNode = Methods.hookFromFreeNode;
        pub const hookFromOwnedNode = Methods.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = Methods.hookFromOwnedConstNode;

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
            self.insertLast(node);
            self.first_ = node;
        }

        pub fn insertLast(self: *@This(), node: *Node) void {
            if (self.first_) |first_node| {
                const last_node = self.last().?;
                self.insertBetween(last_node, first_node, node);
            } else {
                const hook = self.hookFromFreeNode(node);
                hook.* = .{
                    .prev = node,
                    .next = node,
                    .ownership_token_storage = .from(self),
                };

                self.first_ = node;
            }
        }

        pub fn insertBefore(
            self: *@This(),
            next_node: *Node,
            node: *Node,
        ) void {
            if (next_node == self.first_) {
                self.insertFirst(node);
            } else {
                const prev_node = self.hookFromOwnedNode(next_node).prev;
                self.insertBetween(prev_node, next_node, node);
            }
        }

        pub fn insertAfter(
            self: *@This(),
            prev_node: *Node,
            node: *Node,
        ) void {
            if (prev_node == self.last()) {
                self.insertLast(node);
            } else {
                const next_node = self.hookFromOwnedNode(prev_node).next;
                self.insertBetween(prev_node, next_node, node);
            }
        }

        fn insertBetween(
            self: *@This(),
            prev_node: *Node,
            next_node: *Node,
            node: *Node,
        ) void {
            const prev_hook = self.hookFromOwnedNode(prev_node);
            const next_hook = self.hookFromOwnedNode(next_node);
            std.debug.assert(prev_hook.next == next_node);
            std.debug.assert(next_hook.prev == prev_node);

            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .prev = prev_node,
                .next = next_node,
                .ownership_token_storage = .from(self),
            };

            prev_hook.next = node;
            next_hook.prev = node;
        }

        pub fn remove(self: *@This(), node: *Node) void {
            const hook = self.hookFromOwnedNode(node);
            std.debug.assert((hook.prev == node) == (hook.next == node));

            if (hook.next == node) { // is the only node in the list
                std.debug.assert(node == self.first_);
                self.first_ = null;
            } else {
                if (node == self.first_)
                    self.first_ = hook.next;
                self.hookFromOwnedNode(hook.prev).next = hook.next;
                self.hookFromOwnedNode(hook.next).prev = hook.prev;
            }

            hook.* = .{};
        }

        // -------------------- standard inspection

        pub fn first(self: *const @This()) ?*Node {
            return self.first_;
        }

        pub fn last(self: *const @This()) ?*Node {
            return if (self.first_) |first_node|
                self.hookFromOwnedConstNode(first_node).prev
            else
                null;
        }

        pub fn next(self: *const @This(), node: *const Node) ?*Node {
            const next_node = self.hookFromOwnedConstNode(node).next;
            return if (next_node == self.first_)
                null
            else
                next_node;
        }

        pub fn prev(self: *const @This(), node: *const Node) ?*Node {
            return if (node == self.first_)
                null
            else
                self.hookFromOwnedConstNode(node).prev;
        }

        pub fn hasContent(self: *const @This()) bool {
            return self.first_ != null;
        }

        pub const popFirst = Methods.popFirst;
        pub const popLast = Methods.popLast;
        pub const removeAll = Methods.removeAll;
    };
}
