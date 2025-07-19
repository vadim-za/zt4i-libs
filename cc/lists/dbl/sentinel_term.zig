const std = @import("std");
const builtin = @import("builtin");
const lib = @import("../../lib.zig");
const CommonMethods = @import("../common.zig").Methods;
const insertion = @import("insertion.zig");

/// This double-linked list stores the pointers to the first and last elements.
/// The termination is indicated by prev/next pointers pointing to the
/// sentinel node embedded into the list. This allows faster list manipulation
/// but a bit more involved inspection. The more expensive inspection is due
/// to Zig Issue #20254. If the issue persists, the intention is to add an
/// alternative list inspection API, which circumvents the problem.
pub fn List(
    Payload: type,
    layout: lib.Layout,
    ownership_tracking: lib.OwnershipTracking,
) type {
    return struct {
        // These fields are private
        sentinel: Hook,
        ownership_token_storage: OwnershipTraits.ContainerTokenStorage,

        /// This field may be accessed publicly to set the internal
        /// state of a non-empty layout. The layout type still must
        /// be default-initializable with .{} even if it's non-empty.
        layout: Layout = .{},

        const Self = @This();

        pub const Layout = layout.make(@This(), Payload);
        const OwnershipTraits = ownership_tracking.TraitsFor(@This());

        pub const Node = Layout.Node;
        pub const Hook = struct {
            next: *Hook = undefined,
            prev: *Hook = undefined,
            ownership_token_storage: OwnershipTraits.ItemTokenStorage = .{},
            node: if (debug_nodes) ?*Node else void =
                if (debug_nodes) null,
        };

        const debug_nodes = builtin.mode == .Debug;

        pub fn init(self: *@This()) void {
            // Initialize one by one to make it easier on the compiler
            // and considering Zig Issue #24313. If the latter is fixed
            // could change this to self.* = ....
            self.ownership_token_storage = .{};
            self.sentinel = .{
                .next = &self.sentinel,
                .prev = &self.sentinel,
                .ownership_token_storage = .initialFrom(self),
                .node = if (debug_nodes) null,
            };
            // self.layout is either empty or must be initialized by the user
        }

        pub fn setOwnershipToken(
            self: *@This(),
            token: OwnershipTraits.Token,
        ) void {
            OwnershipTraits.setContainerToken(self, token);
            self.sentinel.ownership_token_storage = .from(self);
        }

        pub fn deinit(self: *const @This()) void {
            if (comptime !OwnershipTraits.can_discard_content)
                std.debug.assert(!self.hasContent());
        }

        const Methods = CommonMethods(@This());
        pub const hookFromFreeNode = Methods.hookFromFreeNode;
        pub const hookFromOwnedNode = Methods.hookFromOwnedNode;
        pub const hookFromOwnedConstNode = Methods.hookFromOwnedConstNode;

        pub fn nodeFromOwnedHook(
            self: *const @This(),
            hook: *Hook,
        ) *Node {
            hook.ownership_token_storage.checkOwnership(self);

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
            prev_hook.ownership_token_storage.checkOwnership(self);
            next_hook.ownership_token_storage.checkOwnership(self);
            std.debug.assert(prev_hook.next == next_hook);
            std.debug.assert(next_hook.prev == prev_hook);

            const hook = self.hookFromFreeNode(node);
            hook.* = .{
                .prev = prev_hook,
                .next = next_hook,
                .ownership_token_storage = .from(self),
                .node = if (comptime debug_nodes) node,
            };

            prev_hook.next = hook;
            next_hook.prev = hook;
        }

        pub fn remove(self: *@This(), node: *Node) void {
            const hook = self.hookFromOwnedNode(node);

            hook.prev.next = hook.next;
            hook.next.prev = hook.prev;

            hook.* = .{};
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

        pub const popFirst = Methods.popFirst;
        pub const popLast = Methods.popLast;
        pub const removeAll = Methods.removeAll;
    };
}
