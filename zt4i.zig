const std = @import("std");

pub const gui = @import("gui/lib.zig");
pub const cc = @import("cc/lib.zig");

comptime {
    std.testing.refAllDecls(@This());
}
