const std = @import("std");

pub const gui = @import("gui/lib.zig");

comptime {
    std.testing.refAllDecls(@This());
}
