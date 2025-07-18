const std = @import("std");

pub fn Methods(Container: type) type {
    return struct {
        const Node = Container.Node;
        const Hook = Container.Hook;

        // TODO:
        /// Doesn't move ownership, the new list is rather readonly
        pub fn uncheckedCopyFrom(
            self: *Container,
            from: *const Container,
        ) void {
            self.* = from.*;
            if (comptime std.debug.runtime_safety)
                self.check_ownership = false;
        }

        /// Moves ownership, the old list is still readable
        pub fn uncheckedMoveFrom(
            self: *Container,
            from: *const Container,
        ) void {
            self.* = from.*;
            if (comptime std.debug.runtime_safety)
                self.check_ownership = false;
        }

        /// Moves ownership, the old list is still readable
        pub fn moveFrom(self: *Container, from: *Container) void {
            self.* = from.*;

            if (comptime std.debug.runtime_safety) {
                if (from.check_ownership) {
                    from.check_ownership = false;

                    var node = self.first();
                    while (node) |n| : (node = self.next(n))
                        n.owner = self;
                }
            }
        }

        pub fn hookFromFreeNode(self: *const Container, node: *Node) *Hook {
            // Free nodes have undefined hooks, so we cannot check ownership
            return @constCast(self.layout.hookFromNode(node));
        }

        pub fn hookFromOwnedNode(self: *const Container, node: *Node) *Hook {
            return @constCast(self.hookFromOwnedConstNode(node));
        }

        pub fn hookFromOwnedConstNode(
            self: *const Container,
            node: *const Node,
        ) *const Hook {
            const hook = self.layout.hookFromNode(node);
            if (comptime std.debug.runtime_safety) {
                if (self.check_ownership)
                    std.debug.assert(hook.owner == self);
            }
            return hook;
        }
    };
}
