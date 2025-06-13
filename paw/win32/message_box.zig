const std = @import("std");
const os = std.os.windows;

const paw = @import("../paw.zig");
const Wtf16Str = @import("Wtf16Str.zig");

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

fn toResult(os_result: c_int) paw.Error!Result {
    // Check if OS returned an error.
    if (os_result == 0)
        return paw.Error.OsApi;

    // If OS returns unexpected code, treat this as OS API error.
    return std.meta.intToEnum(
        Result,
        os_result,
    ) catch paw.Error.OsApi;
}

// This function coverts strings to WTF16 at comptime
// and therefore doesn't use allocator.
pub fn showComptime(
    comptime caption: []const u8,
    comptime text: []const u8,
    @"type": Type,
) paw.Error!Result {
    const text16 = std.unicode.wtf8ToWtf16LeStringLiteral(text);
    const caption16 = std.unicode.wtf8ToWtf16LeStringLiteral(caption);

    const os_result = MessageBoxW(
        null,
        text16.ptr,
        caption16.ptr,
        @intFromEnum(@"type"),
    );

    return toResult(os_result);
}

// This function uses paw.allocator() to convert strings to WTF16
pub fn show(
    caption: [:0]const u8,
    text: [:0]const u8,
    @"type": Type,
) paw.Error!Result {
    const text16: Wtf16Str = try .initU8(text);
    defer text16.deinit();

    const caption16: Wtf16Str = try .initU8(caption);
    defer caption16.deinit();

    const os_result = MessageBoxW(
        null,
        text16.ptr(),
        caption16.ptr(),
        @intFromEnum(@"type"),
    );

    return toResult(os_result);
}
