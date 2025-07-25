const std = @import("std");
const builtin = @import("builtin");

owned_items: TrackOwnedItems,
free_items: TrackFreeItems,

/// How to track items owned by a container
pub const TrackOwnedItems = union(enum) {
    /// Ownership is not tracked. In non-debug builds the ownership
    /// tracking is always off.
    off: void,

    /// Pointer to the container object is used as the ownership token
    container_ptr: void,

    /// So far only types comparable with '==' are supported
    custom: type,
};

/// Whether free items should be tracked as being free
pub const TrackFreeItems = enum {
    /// The item state of being free (not in a container) is tracked.
    /// You must explicitly remove an item from a container before
    /// being able to reuse it in another container, simple discarding
    /// of containers is not supported.
    on,

    /// The item state of being free (not in a container) is not tracked.
    /// You may simply discard a container and reuse its items
    /// in another container right away.
    off,
};

pub fn TraitsFor(spec: @This(), Container: type) type {

    // Tracking is never enabled in non-safe modes, some non-safe
    // code may be incompatible with enabled tracking.
    const tracking_allowed = comptime builtin.mode == .Debug;

    return struct {
        const track_owned: TrackOwnedItems =
            if (tracking_allowed) spec.owned_items else .off;
        const track_free: TrackFreeItems =
            if (tracking_allowed) spec.free_items else .off;
        pub const can_discard_content = track_free == .off;

        // Token type actually passed around
        const PassedAroundToken: type =
            if (tracking_allowed) Token else void;

        // Token type as requested by the user (to be used in user-side API)
        pub const Token: type = switch (spec.owned_items) {
            .off => void,
            .container_ptr => *const Container,
            .custom => |T| T,
        };

        pub const ContainerTokenStorage: type = switch (track_owned) {
            .off => struct {},
            .container_ptr => struct {},
            .custom => |T| struct { token: ?T = null },
        };

        inline fn getContainerToken(
            container: *const Container,
        ) PassedAroundToken {
            return switch (comptime track_owned) {
                .off => {},
                .container_ptr => container,
                .custom => container.ownership_token_storage.token.?,
            };
        }

        // Call this function to obtain the value that would be returned
        // by the container after the container has been initialized
        inline fn initialContainerToken(
            container: *const Container,
        ) PassedAroundToken {
            return switch (comptime track_owned) {
                .off => {},
                .container_ptr => container,
                .custom => undefined, // no initial value, must be set by the user
            };
        }

        // This one is part of the user-side API implementation, use Token,
        // not PassedAroundToken
        pub inline fn setContainerToken(
            container: *Container,
            token: Token,
        ) void {
            switch (spec.owned_items) {
                .custom => {
                    if (comptime tracking_allowed)
                        container.ownership_token_storage = .{ .token = token };
                },
                else => @compileError("Tracking mode " ++
                    @tagName(track_owned) ++ " doesn't support setContainerToken()"),
            }
        }

        pub const ItemTokenStorage: type = switch (track_owned) {
            .off => struct {
                pub fn from(_: *const Container) @This() {
                    return .{};
                }
                pub fn initialFrom(_: *const Container) @This() {
                    return .{};
                }
                pub inline fn checkOwnership(
                    _: *const @This(),
                    _: *const Container,
                ) void {}
                pub inline fn checkFree(
                    _: *const @This(),
                ) void {}
            },
            else => struct {
                token: ?PassedAroundToken = switch (track_free) {
                    .off => undefined,
                    .on => null,
                },
                pub fn from(container: *const Container) @This() {
                    return .{ .token = getContainerToken(container) };
                }
                pub fn initialFrom(container: *const Container) @This() {
                    return .{ .token = initialContainerToken(container) };
                }
                pub inline fn checkOwnership(
                    self: *const @This(),
                    container: *const Container,
                ) void {
                    std.debug.assert(self.token.? == getContainerToken(container));
                }
                pub inline fn checkFree(
                    self: *const @This(),
                ) void {
                    switch (comptime track_free) {
                        .off => {},
                        .on => std.debug.assert(self.token == null),
                    }
                }
            },
        }; // ItemTokenStorage
    };
}
