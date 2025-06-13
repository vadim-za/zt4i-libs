const std = @import("std");

// --------------------------------------------------------------
// Common decls

pub const Error = error{
    OsApi, // OS API call returned an error
    Usage, // PAW incorrectly used
};

// --------------------------------------------------------------
// Platforms

pub const win32 = @import("win32.zig");

// Current platform
const platform = win32;

// Platform reexports
pub const allocator = platform.allocator;
pub const message_box = platform.message_box;

// Conditional platform reexports
pub const wWinMain =
    if (platform == win32) platform.wWinMain;
