const std = @import("std");

pub const paw = @import("paw/paw.zig");

comptime {
    std.testing.refAllDecls(@This());
}
