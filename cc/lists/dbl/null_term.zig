const std = @import("std");
const lib = @import("../../lib.zig");
const CommonMethods = @import("../common.zig").Methods;
const insertion = @import("insertion.zig");

/// This double-linked list stores the pointers to the first and last elements.
/// The termination is indicated by prev/next pointers set to null.
pub fn List(
    Payload: type,
    layout: lib.Layout,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        first_: ?*Node = null,
        last_: ?*Node = null,
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
            next: ?*Node,
            prev: ?*Node,
            owner: OwnershipTraits.Token,
        };

        pub fn init(self: *@This()) void {
            self.* = .{};
        }

        pub const setOwnershipToken = OwnershipTraits.setContainerToken;

        const Methods = CommonMethods(@This(), OwnershipTraits);
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
            const hook = self.hookFromFreeNode(node);

            hook.prev = null;
            hook.next = self.first_;
            hook.owner = OwnershipTraits.getContainerToken(self);

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
            hook.owner = OwnershipTraits.getContainerToken(self);

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

            hook.owner = OwnershipTraits.getContainerToken(self);
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

            hook.owner = OwnershipTraits.getContainerToken(self);
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

            if (comptime std.debug.runtime_safety)
                hook.* = undefined;
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

        pub const popFirst = Methods.popFirst;
        pub const popLast = Methods.popLast;
    };
}
