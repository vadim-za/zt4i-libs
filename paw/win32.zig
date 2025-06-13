const winmain = @import("win32/winmain.zig");
pub const wWinMain = winmain.wWinMain;
pub const allocator = winmain.allocator;

pub const message_box = @import("win32/message_box.zig");
pub const Window = @import("win32/Window.zig");

// --------------------------------------------------------------

const std = @import("std");

comptime {
    std.testing.refAllDecls(Window);
}
