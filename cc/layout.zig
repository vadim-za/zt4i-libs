pub const Layout = union(enum) {
    simple_payload: void,
    embedded_hook: []const u8,
    custom: type,

    pub fn make(self: @This(), List: type, Payload: type) type {
        const generic = switch (self) {
            .simple_payload => SimplePayload,
            .embedded_hook => |hook_field_name| EmbeddedHook(
                hook_field_name,
            ),
            .custom => |custom_layout| return custom_layout
                .With(List.Hook),
        };
        return generic.With(Payload, List.Hook);
    }
};

fn EmbeddedHook(
    hook_field_name: []const u8,
) type {
    return struct {
        pub fn With(Payload: type, Hook: type) type {
            return struct {
                pub const Node = Payload;

                /// This function is required by all implementations
                pub inline fn hookFromNode(_: @This(), node: *Node) *Hook {
                    return &@field(node, hook_field_name);
                }

                /// This function is required by some but not all implementations
                pub inline fn nodeFromHook(_: @This(), hook: *Hook) *Node {
                    return @alignCast(@fieldParentPtr(hook_field_name, hook));
                }
            };
        }
    };
}

const SimplePayload = struct {
    pub fn With(Payload: type, Hook: type) type {
        const Node = struct {
            data: Payload,
            hook: Hook,
        };
        return EmbeddedHook("hook").With(Node, Hook);
    }
};
