const std = @import("std");
const lib = @import("../../lib.zig");

pub fn List(
    Payload: type,
    layout: lib.Layout,
) type {
    return struct {
        // These fields are private
        head: ?*Node = null,
        tail: ?*Node = null,

        /// This field may be accessed publicly to set the internal
        /// state of a non-empty layout. The layout type still must
        /// be default-initializable with .{} even if it's non-empty.
        layout: Layout = .{},

        /// This field may be accessed publicly to disable the
        /// ownership tracking for a given list.
        /// NB. Ownership tracking is always disabled on comptime
        /// level in non-safe builds.
        track_ownership: bool = true,

        const Self = @This();

        const Layout = layout.make(@This(), Payload);
        const Node = Layout.Node;

        pub const Hook = struct {
            next: ?*Node = undefined,
            prev: ?*Node = undefined,
            owner: if (std.debug.runtime_safety) ?*Self else void =
                if (std.debug.runtime_safety) null,
        };
    };
}
