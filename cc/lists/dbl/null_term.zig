const std = @import("std");
const lib = @import("../../lib.zig");

pub fn List(
    Payload: type,
    layout: lib.Layout,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        last_: ?*Node = null,
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
            next: ?*Node,
            prev: ?*Node,
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

        fn hookFromFreeNode(self: *@This(), node: *Node) *Hook {
            // Free nodes can have undefined ownership, which we cannot check
            return self.layout.hookFromNode(node);
        }

        fn hookFromOwnedNode(self: *@This(), node: *Node) *Hook {
            const hook = self.layout.hookFromNode(node);
            if (comptime std.debug.runtime_safety) {
                if (self.check_ownership)
                    std.debug.assert(hook.owner == self);
            }
            return hook;
        }

        pub const InsertionPos = lib.lists.InsertionPos(Node);

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

            hook.prev = null;
            hook.next = self.first_;
            if (comptime std.debug.runtime_safety)
                hook.owner = self;

            if (self.first_) |first_node|
                self.hookFromOwnedNode(first_node).prev = node
            else
                self.last_ = node;

            self.first_ = node;
        }

        pub fn insertLast(self: *@This(), node: *Node) void {
            const hook = self.hookFromFreeNode(node);

            hook.prev = self.last_;
            hook.next = null;
            if (comptime std.debug.runtime_safety)
                hook.owner = self;

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
            hook.next = next_node;

            const next_hook = self.hookFromOwnedNode(next_node);
            if (next_hook.prev) |prev_node| {
                std.debug.assert(next_node != self.first_);
                hook.prev = prev_node;

                const prev_hook = self.hookFromOwnedNode(prev_node);
                prev_hook.next = node;
            } else {
                std.debug.assert(next_node == self.first_);
                hook.prev = null;
                self.first_ = node;
            }

            next_hook.prev = node;

            if (comptime std.debug.runtime_safety)
                hook.owner = self;
        }

        pub fn insertAfter(
            self: *@This(),
            prev_node: *Node,
            node: *Node,
        ) void {
            const hook = self.hookFromFreeNode(node);
            hook.prev = prev_node;

            const prev_hook = self.hookFromOwnedNode(prev_node);
            if (prev_hook.next) |next_node| {
                std.debug.assert(prev_node != self.last_);
                hook.next = next_node;

                const next_hook = self.hookFromOwnedNode(next_node);
                next_hook.prev = node;
            } else {
                std.debug.assert(prev_node == self.last_);
                hook.next = null;
                self.last_ = node;
            }

            prev_hook.next = node;

            if (comptime std.debug.runtime_safety)
                hook.owner = self;
        }
    };
}
