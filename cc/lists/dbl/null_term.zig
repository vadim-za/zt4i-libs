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

        pub inline fn disableOwnershipChecking(self: *@This()) void {
            if (comptime std.debug.runtime_safety)
                self.check_ownership = false;
        }

        pub fn hookFromFreeNode(self: *@This(), node: *Node) *Hook {
            // Free nodes can have undefined ownership, which we cannot check
            return self.layout.hookFromNode(node);
        }

        pub fn hookFromOwnedNode(self: *@This(), node: *Node) *Hook {
            const hook = self.layout.hookFromNode(node);
            if (comptime std.debug.runtime_safety) {
                if (self.check_ownership)
                    std.debug.assert(hook.owner == self);
            }
            return hook;
        }

        pub const InsertionPos = lib.lists.InsertionPos;

        // pub inline fn insert(self: *@This(), where: InsertionPos, node: *Node) void {
        //     switch (where) {
        //         .first_ => self.insertFirst(node),
        //         .last_ => self.insertLast(node),
        //         .before_ => |next_node| self.insertBefore(next_node, node),
        //         .after_ => |prev_node| self.insertAfter(prev_node, node),
        //     }
        // }

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
    };
}
