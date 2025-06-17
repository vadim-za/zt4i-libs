const std = @import("std");

pub const gui = @import("gui/gui.zig");

comptime {
    std.testing.refAllDecls(@This());
}
