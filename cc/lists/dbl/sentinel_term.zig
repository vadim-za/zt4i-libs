const std = @import("std");
const builtin = @import("builtin");
const lib = @import("../../lib.zig");
const CommonMethods = @import("../common.zig").Methods;
const insertion = @import("insertion.zig");

pub fn List(
    Payload: type,
    layout: lib.Layout,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        sentinel: Hook,
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
            next: *Hook,
            prev: *Hook,
            owner: OwnershipTraits.Token,
            node: if (debug_nodes) ?*Node else void,
        };

        const debug_nodes = builtin.mode == .Debug;

        pub fn init(self: *@This()) void {
            self.sentinel = .{
                .next = &self.sentinel,
                .prev = &self.sentinel,
                .owner = if (std.debug.runtime_safety) self,
                .node = if (debug_nodes) null,
            };
        }

        const Methods = CommonMethods(@This(), OwnershipTraits);
        pub const hookFromFreeNode = Methods.hookFromFreeNode;
        pub const hookFromOwnedNode = Methods.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = Methods.hookFromOwnedConstNode;

        pub fn nodeFromOwnedHook(
            self: *const @This(),
            hook: *Hook,
        ) *Node {
            OwnershipTraits.checkOwnership(self, &hook.owner);

            const node = self.layout.nodeFromHook(hook);
            if (comptime debug_nodes)
                std.debug.assert(node == hook.node);

            return @constCast(node);
        }

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
            self.insertBetween(&self.sentinel, self.sentinel.next, node);
        }

        pub fn insertLast(self: *@This(), node: *Node) void {
            self.insertBetween(self.sentinel.prev, &self.sentinel, node);
        }

        pub fn insertBefore(
            self: *@This(),
            next_node: *Node,
            node: *Node,
        ) void {
            const next_hook = self.hookFromOwnedNode(next_node);
            self.insertBetween(next_hook.prev, next_hook, node);
        }

        pub fn insertAfter(
            self: *@This(),
            prev_node: *Node,
            node: *Node,
        ) void {
            const prev_hook = self.hookFromOwnedNode(prev_node);
            self.insertBetween(prev_hook, prev_hook.next, node);
        }

        fn insertBetween(
            self: *@This(),
            prev_hook: *Hook,
            next_hook: *Hook,
            node: *Node,
        ) void {
            if (comptime std.debug.runtime_safety) {
                std.debug.assert(prev_hook.owner == self);
                std.debug.assert(next_hook.owner == self);
            }
            std.debug.assert(prev_hook.next == next_hook);
            std.debug.assert(next_hook.prev == prev_hook);

            const hook = self.hookFromFreeNode(node);
            hook.prev = prev_hook;
            hook.next = next_hook;
            hook.owner = OwnershipTraits.getContainerToken(self);
            if (comptime debug_nodes)
                hook.node = node;

            prev_hook.next = hook;
            next_hook.prev = hook;
        }

        pub fn remove(self: *@This(), node: *Node) void {
            const hook = self.hookFromOwnedNode(node);

            hook.prev.next = hook.next;
            hook.next.prev = hook.prev;

            if (comptime std.debug.runtime_safety)
                hook.* = undefined;
        }

        // -------------------- standard inspection

        pub fn first(self: *const @This()) ?*Node {
            return if (self.hasContent())
                self.nodeFromOwnedHook(self.sentinel.next)
            else
                null;
        }

        pub fn last(self: *const @This()) ?*Node {
            return if (self.hasContent())
                self.nodeFromOwnedHook(self.sentinel.prev)
            else
                null;
        }

        pub fn next(self: *const @This(), node: *const Node) ?*Node {
            const hook = self.hookFromOwnedConstNode(node);
            return if (hook.next == &self.sentinel)
                null
            else
                self.nodeFromOwnedHook(hook.next);
        }

        pub fn prev(self: *const @This(), node: *const Node) ?*Node {
            const hook = self.hookFromOwnedConstNode(node);
            return if (hook.prev == &self.sentinel)
                null
            else
                self.nodeFromOwnedHook(hook.prev);
        }

        pub fn hasContent(self: *const @This()) bool {
            std.debug.assert((self.sentinel.next != &self.sentinel) ==
                (self.sentinel.prev != &self.sentinel));
            return self.sentinel.next != &self.sentinel;
        }
    };
}
