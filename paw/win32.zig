const winmain = @import("win32/winmain.zig");
pub const wWinMain = winmain.wWinMain;
pub const allocator = winmain.allocator;

pub const message_box = @import("win32/message_box.zig");
pub const message_loop = @import("win32/message_loop.zig");
pub const Window = @import("win32/Window.zig");
pub const graphics = @import("win32/graphics.zig");

// --------------------------------------------------------------

const std = @import("std");

comptime {
    std.testing.refAllDecls(@import("win32/Wtf16Str.zig"));
}
