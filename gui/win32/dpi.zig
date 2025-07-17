const std = @import("std");
const os = std.os.windows;

const gui = @import("../gui.zig");

// ----------------------------------------------------------------

extern "user32" fn SetProcessDpiAwarenessContext(
    value: DPI_AWARENESS_CONTEXT,
) callconv(.winapi) os.BOOL;

const DPI_AWARENESS_CONTEXT = ?*opaque {};

const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: DPI_AWARENESS_CONTEXT =
    @ptrFromInt(-%@as(usize, 4));

extern "user32" fn GetDpiForWindow(hWnd: os.HWND) callconv(.winapi) os.UINT;

// ----------------------------------------------------------------

pub fn setupDpiAwareness() gui.Error!void {
    if (SetProcessDpiAwarenessContext(
        DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    ) == 0)
        return gui.Error.OsApi;
}

pub fn getDpiAndDprFor(hWnd: os.HWND) struct { os.UINT, f32 } {
    var dpi = GetDpiForWindow(hWnd);

    if (dpi == 0)
        dpi = 96;

    const dpr = @as(f32, @floatFromInt(dpi)) / 96;
    return .{ dpi, dpr };
}

// Physical coordinates are supposed to be i32, but we return
// f32 and let the caller decide on the rounding details.
pub fn physicalFromLogical(dpr: f32, logical: f32) f32 {
    return logical * dpr;
}

pub fn logicalFromPhysical(dpr: f32, physical: i32) f32 {
    return @as(f32, @floatFromInt(physical)) / dpr;
}
