const std = @import("std");

pub fn Methods(Container: type) type {
    return struct {
        const Node = Container.Node;
        const Hook = Container.Hook;

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
            hook.ownership_token_storage.checkOwnership(self);
            return hook;
        }

        pub fn popFirst(self: *Container) ?*Node {
            if (self.first()) |node| {
                self.remove(node);
                return node;
            }
            return null;
        }

        pub fn popLast(self: *Container) ?*Node {
            if (self.last()) |node| {
                self.remove(node);
                return node;
            }
            return null;
        }

        pub fn removeAll(self: *Container) void {
            while (self.last()) |node|
                self.remove(node);
        }
    };
}
