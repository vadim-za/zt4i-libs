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

pub fn getDprFor(hWnd: os.HWND) f32 {
    var dpi = GetDpiForWindow(hWnd);

    if (dpi == 0)
        dpi = 96;

    return @as(f32, @floatFromInt(dpi)) / 96;
}

pub fn physicalFromLogical(dpr: f32, logical: f32) f32 {
    return logical * dpr;
}

pub fn logicalFromPhysical(dpr: f32, physical: i32) f32 {
    return physical / dpr;
}
