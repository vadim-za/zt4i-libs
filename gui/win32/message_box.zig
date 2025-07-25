const std = @import("std");
const lib = @import("../lib.zig");
const unicode = @import("unicode.zig");
const winmain = @import("winmain.zig");
const debug = @import("debug.zig");

const os = std.os.windows;

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

fn toResult(os_result: c_int) lib.Error!Result {
    // Check if OS returned an error.
    if (os_result == 0)
        return lib.Error.OsApi;

    // If OS returns unexpected code, treat this as OS API error.
    return std.meta.intToEnum(
        Result,
        os_result,
    ) catch lib.Error.OsApi;
}

pub fn showWtf16(
    parent_window: ?*lib.Window,
    caption: [:0]const u16,
    text: [:0]const u16,
    @"type": Type,
) lib.Error!Result {
    const os_result = MessageBoxW(
        if (parent_window) |window| window.hWnd else null,
        text,
        caption,
        @intFromEnum(@"type"),
    );
    return toResult(os_result);
}

// This function coverts strings to WTF16 at comptime
// and therefore doesn't use allocator.
pub fn showComptime(
    parent_window: ?*lib.Window,
    comptime caption: []const u8,
    comptime text: []const u8,
    @"type": Type,
) lib.Error!Result {
    return showWtf16(
        parent_window,
        std.unicode.wtf8ToWtf16LeStringLiteral(caption),
        std.unicode.wtf8ToWtf16LeStringLiteral(text),
        @"type",
    );
}

// This function uses lib.allocator() to convert strings to WTF16
pub fn show(
    parent_window: ?*lib.Window,
    caption: []const u8,
    text: []const u8,
    @"type": Type,
) lib.Error!Result {
    var text16: unicode.Wtf16Str(2000) = undefined;
    try text16.initU8(text);
    defer text16.deinit();

    var caption16: unicode.Wtf16Str(200) = undefined;
    try caption16.initU8(caption);
    defer caption16.deinit();

    return showWtf16(
        parent_window,
        caption16.slice(),
        text16.slice(),
        @"type",
    );
}

// Doesn't use allocator.
// Doesn't fail.
// Blocks window and timer callbacks for good
//(to prevent potential further panics).
// 'text' will be clipped to 'max_text_len' WTF16 characters.
// To be used only inside panic handlers.
pub fn showPanic(
    comptime caption: []const u8,
    text: []const u8,
    comptime max_text_len: usize,
) void {
    var buf16: unicode.BoundedWtf16Str(max_text_len) = undefined;
    const text16 = if (buf16.initU8(text))
        buf16.slice()
    else |_|
        std.unicode.wtf8ToWtf16LeStringLiteral(
            "Failed to convert panic message",
        );

    winmain.enterPanicMode();

    _ = showWtf16(
        null,
        std.unicode.wtf8ToWtf16LeStringLiteral(caption),
        text16,
        .ok,
    ) catch debug.safeModePanic("Failed to display panic message");
}
