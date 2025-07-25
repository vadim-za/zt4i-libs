const std = @import("std");
const builtin = @import("builtin");

pub fn For(Container: type, hook_field_name: []const u8) type {
    return struct {
        const Node = Container.Node;
        const Hook = Container.Hook;

        pub fn hookFromFreeNode(self: *const Container, node: *Node) *Hook {
            _ = self;
            const hook = &@field(node, hook_field_name);
            hook.ownership_token_storage.checkFree();
            return @constCast(hook);
        }

        pub fn hookFromOwnedNode(
            self: *const Container,
            node: *Node,
        ) *Hook {
            const hook = &@field(node, hook_field_name);
            hook.ownership_token_storage.checkOwnership(self);
            return hook;
        }

        pub fn hookFromOwnedConstNode(
            self: *const Container,
            node: *const Node,
        ) *const Hook {
            const hook = &@field(node, hook_field_name);
            hook.ownership_token_storage.checkOwnership(self);
            return hook;
        }

        const debug_nodes = builtin.mode == .Debug;
        pub const NodeDebugPtr = if (debug_nodes) ?*Node else void;
        pub const init_node_debug_ptr: NodeDebugPtr = if (debug_nodes) null;

        // If the container uses this method, it should have a 'node'
        // field in the hook declared as:
        //      node: HookCommon.NodeDebugPtr = HookCommon.init_node_debug_ptr,
        pub fn nodeFromOwnedHook(
            self: *const Container,
            hook: *Hook,
        ) *Node {
            hook.ownership_token_storage.checkOwnership(self);

            const node: *Node = @alignCast(@fieldParentPtr(
                hook_field_name,
                hook,
            ));

            if (comptime debug_nodes)
                std.debug.assert(node == hook.node);
        }
    };
}
