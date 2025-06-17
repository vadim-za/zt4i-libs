const std = @import("std");
const os = std.os.windows;

const gui = @import("../gui.zig");
const unicode = @import("unicode.zig");

// ----------------------------------------------------------------

extern "user32" fn MessageBoxW(
    hWnd: ?os.HWND,
    lpText: os.LPCWSTR,
    lpCaption: os.LPCWSTR,
    uType: os.UINT,
) callconv(.winapi) c_int;

// ----------------------------------------------------------------

// Map directly to WinAPI MB_... constants
pub const Type = enum(os.UINT) {
    ok = 0,
    okCancel = 1,
    abortRetryIgnore = 2,
    yesNoCancel = 3,
    yesNo = 4,
    retryCancel = 5,
};

// Map directly to WinAPI ID... constants
pub const Result = enum(c_int) {
    ok = 1,
    cancel = 2,
    abort = 3,
    retry = 4,
    ignore = 5,
    yes = 6,
    no = 7,
};

fn toResult(os_result: c_int) gui.Error!Result {
    // Check if OS returned an error.
    if (os_result == 0)
        return gui.Error.OsApi;

    // If OS returns unexpected code, treat this as OS API error.
    return std.meta.intToEnum(
        Result,
        os_result,
    ) catch gui.Error.OsApi;
}

// This function coverts strings to WTF16 at comptime
// and therefore doesn't use allocator.
pub fn showComptime(
    parent_window: ?*gui.Window,
    comptime caption: []const u8,
    comptime text: []const u8,
    @"type": Type,
) gui.Error!Result {
    const text16 = std.unicode.wtf8ToWtf16LeStringLiteral(text);
    const caption16 = std.unicode.wtf8ToWtf16LeStringLiteral(caption);

    const os_result = MessageBoxW(
        if (parent_window) |window| window.hWnd else null,
        text16.ptr,
        caption16.ptr,
        @intFromEnum(@"type"),
    );

    return toResult(os_result);
}

// This function uses gui.allocator() to convert strings to WTF16
pub fn show(
    parent_window: ?*gui.Window,
    caption: [:0]const u8,
    text: [:0]const u8,
    @"type": Type,
) gui.Error!Result {
    var text16: unicode.Wtf16Str(2000) = undefined;
    try text16.initU8(text);
    defer text16.deinit();

    var caption16: unicode.Wtf16Str(200) = undefined;
    try caption16.initU8(caption);
    defer caption16.deinit();

    const os_result = MessageBoxW(
        if (parent_window) |window| window.hWnd else null,
        text16.ptr(),
        caption16.ptr(),
        @intFromEnum(@"type"),
    );

    return toResult(os_result);
}
