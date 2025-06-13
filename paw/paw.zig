const std = @import("std");

// Platforms
pub const win32 = @import("win32.zig");

// Current platform
const platform = win32;

// Conditional platform reexports
pub const wWinMain =
    if (platform == win32) platform.wWinMain;
