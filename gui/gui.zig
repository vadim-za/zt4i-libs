const std = @import("std");

// --------------------------------------------------------------
// Common decls

pub const Error = error{
    OsApi, // OS API call returned an error
    Usage, // PAW incorrectly used
    OutOfMemory,
};

// --------------------------------------------------------------
// Platform-independent decls

pub const mouse = @import("mouse.zig");

// --------------------------------------------------------------
// Platforms

pub const win32 = @import("win32.zig");

// Current platform
const platform = win32;

// Platform reexports
pub const allocator = platform.allocator;

pub const message_box = platform.message_box;
pub const showMessageBox = message_box.show;
pub const showComptimeMessageBox = message_box.showComptime;

pub const message_loop = platform.message_loop;
pub const runMessageLoop = message_loop.run;
pub const stopMessageLoop = message_loop.stop;

pub const Window = platform.Window;

pub const graphics = platform.graphics;
pub const BrushRef = graphics.BrushRef;
pub const SolidBrush = graphics.SolidBrush;
pub const DeviceResources = graphics.DeviceResources;
pub const DrawContext = graphics.DrawContext;
pub const Path = graphics.Path;
pub const Font = graphics.Font;
pub const Bezier = graphics.Bezier;
pub const Color = graphics.Color;
pub const Point = graphics.Point;
pub const Rectangle = graphics.Rectangle;

// Conditional platform reexports
pub const wWinMain =
    if (platform == win32) platform.wWinMain;

// --------------------------------------------------------------

comptime {
    std.testing.refAllDecls(platform);
}
