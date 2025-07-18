const std = @import("std");
const builtin = @import("builtin");

pub const Tracking = union(enum) {
    /// Ownership is not tracked. In non-debug builds the ownership
    /// tracking is always off.
    off: void,

    /// Pointer to the container object is used as the ownership token
    container_ptr: void,

    /// So far only types comparable with '==' are supported
    custom: type,

    pub fn TraitsFor(self: @This(), Container: type) type {
        const tracking = if (comptime builtin.mode == .Debug)
            self
        else
            .off;

        return struct {
            pub const enabled = tracking != .off;

            pub const Token: type = switch (tracking) {
                .off => void,
                .container_ptr => *const Container,
                .custom => |T| T,
            };

            pub const ContainerTokenStorage: type = switch (tracking) {
                .off => struct {},
                .container_ptr => struct {},
                .custom => |T| struct { token: ?T = null },
            };

            pub inline fn getContainerToken(container: *const Container) Token {
                return switch (comptime tracking) {
                    .off => {},
                    .container_ptr => container,
                    .custom => container.ownership_token_storage.?.token,
                };
            }

            pub inline fn checkOwnership(
                container: *const Container,
                token: *const Token,
            ) void {
                if (comptime tracking != .off)
                    std.debug.assert(token.* == getContainerToken(container));
            }
        };
    }
};
