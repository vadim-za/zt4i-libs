const std = @import("std");
const lib = @import("../../lib.zig");

pub fn List(
    Payload: type,
    layout: lib.Layout,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        check_ownership: if (std.debug.runtime_safety) bool else void =
            if (std.debug.runtime_safety) true,

        /// This field may be accessed publicly to set the internal
        /// state of a non-empty layout. The layout type still must
        /// be default-initializable with .{} even if it's non-empty.
        layout: Layout = .{},

        const Self = @This();

        pub const Layout = layout.make(@This(), Payload);

        pub const Node = Layout.Node;
        pub const Hook = struct {
            next: *Node,
            prev: *Node,
            owner: if (std.debug.runtime_safety) ?*Self else void,
        };

        pub fn init(self: *@This()) void {
            self.* = .{};
        }

        pub inline fn uncheckedCopyFrom(self: *@This(), from: *const @This()) void {
            self.* = from.*;
            if (comptime std.debug.runtime_safety)
                self.check_ownership = false;
        }

        pub inline fn moveFrom(self: *@This(), from: *@This()) void {
            self.* = from.*;

            if (comptime std.debug.runtime_safety) {
                from.check_ownership = false;

                var node = self.first_;
                while (node) |n| : (node = n.next)
                    n.owner = self;
            }
        }

        fn hookFromFreeNode(self: *const @This(), node: *Node) *Hook {
            // Free nodes have undefined hooks, so we cannot check ownership
            return @constCast(self.layout.hookFromNode(node));
        }

        fn hookFromOwnedNode(self: *const @This(), node: *Node) *Hook {
            return @constCast(self.hookFromOwnedConstNode(node));
        }

        fn hookFromOwnedConstNode(
            self: *const @This(),
            node: *const Node,
        ) *const Hook {
            const hook = self.layout.hookFromNode(node);
            if (comptime std.debug.runtime_safety) {
                if (self.check_ownership)
                    std.debug.assert(hook.owner == self);
            }
            return hook;
        }

        // -------------------- insertion/removal

        pub const InsertionPos = lib.lists.Implementation
            .DoubleLinked.InsertionPos(Node);

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
                hook.prev = node;
                hook.next = node;
                if (comptime std.debug.runtime_safety)
                    hook.owner = self;

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
            hook.prev = prev_node;
            hook.next = next_node;
            if (comptime std.debug.runtime_safety)
                hook.owner = self;

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

            if (comptime std.debug.runtime_safety)
                hook.* = undefined;
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
    };
}
