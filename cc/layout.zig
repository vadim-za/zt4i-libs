/// Layout of container nodes
pub const Layout = union(enum) {
    /// Container nodes contain 'data' field of Payload type
    simple_payload: void,

    /// Container nodes are of Payload type, one of the fields is a container hook.
    /// See "Embedded hook" test in lists/dbl/testing.zig
    embedded_hook: []const u8,

    /// Other layout, possibly runtime-configurable.
    /// See "Non-empty layout" test in lists/dbl/testing.zig
    custom: type,

    pub fn make(self: @This(), List: type, Payload: type) type {
        const generic = switch (self) {
            .simple_payload => SimplePayload,
            .embedded_hook => |hook_field_name| EmbeddedHook(
                hook_field_name,
            ),
            .custom => |custom_layout| custom_layout,
        };
        return generic.With(Payload, List.Hook);
    }
};

/// Container nodes are of Payload type, one of the fields is a container hook.
/// See "Embedded hook" test in lists/dbl/testing.zig
fn EmbeddedHook(
    hook_field_name: []const u8,
) type {
    return struct {
        pub fn With(Payload: type, Hook: type) type {
            return struct {
                pub const Node = Payload;

                /// This function is required by all implementations
                pub inline fn hookFromNode(
                    _: @This(),
                    node: *const Node,
                ) *const Hook {
                    return &@field(node, hook_field_name);
                }

                /// This function is required by some but not all implementations
                pub inline fn nodeFromHook(
                    _: @This(),
                    hook: *const Hook,
                ) *const Node {
                    return @alignCast(@fieldParentPtr(hook_field_name, hook));
                }
            };
        }
    };
}

/// List nodes contain 'data' field of Payload type
const SimplePayload = struct {
    pub fn With(Payload: type, Hook: type) type {
        const Node = struct {
            data: Payload,
            hook: Hook,
        };
        return EmbeddedHook("hook").With(Node, Hook);
    }
};
