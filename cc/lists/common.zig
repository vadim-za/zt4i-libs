const std = @import("std");

pub fn Methods(Container: type, OwnershipTraits: type) type {
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
            OwnershipTraits.checkOwnership(self, &hook.owner);
            return hook;
        }
    };
}
