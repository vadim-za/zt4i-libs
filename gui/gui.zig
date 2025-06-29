const std = @import("std");
const builtin = @import("builtin");

// --------------------------------------------------------------
// Common decls

pub const Error = error{
    OsApi, // OS API call returned an error
    Usage, // PAW incorrectly used
    OutOfMemory,
};

// --------------------------------------------------------------
// Platforms

const win32 = @import("win32.zig");

// Current platform
const platform = switch (builtin.os.tag) {
    .windows => win32,
    else => @compileError("Unsupported platform"),
};

// Platform reexports
pub const allocator = platform.allocator;

pub const mbox = struct {
    const impl = platform.message_box;
    pub const show = impl.show;
    pub const showComptime = impl.showComptime;
    pub const showPanic = impl.showPanic;
    pub const Type = impl.Type;
    pub const Result = impl.Result;
};

pub const mloop = struct {
    const impl = platform.message_loop;
    pub const run = impl.run;
    pub const stop = impl.stop;
};

pub const Window = platform.Window;

const graphics = platform.graphics;
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

pub const mouse = platform.mouse;
pub const keys = platform.keys;

pub const Timer = platform.Timer;

// Conditional platform reexports
pub const wWinMain =
    if (platform == win32) platform.wWinMain;

// --------------------------------------------------------------

comptime {
    std.testing.refAllDecls(platform);
}
