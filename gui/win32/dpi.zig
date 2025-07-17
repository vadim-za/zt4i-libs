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

pub const Dpr = struct {
    os_dpi: os.UINT,
    dpr: f32,

    pub fn fromWindow(hWnd: os.HWND) @This() {
        var dpi = GetDpiForWindow(hWnd);

        if (dpi == 0)
            dpi = 96;

        return .{
            .os_dpi = dpi,
            .dpr = @as(f32, @floatFromInt(dpi)) / 96,
        };
    }

    /// Physical coordinates are supposed to be i32, but we return
    /// f32 and let the caller decide on the rounding details.
    pub fn physicalFromLogical(self: *const @This(), logical: f32) f32 {
        return logical * self.dpr;
    }

    pub fn logicalFromPhysical(self: *const @This(), physical: i32) f32 {
        return @as(f32, @floatFromInt(physical)) / self.dpr;
    }

    /// Physical coordinates are supposed to be i32, but we return
    /// f32 and let the caller decide on the rounding details.
    pub fn physicalFromLogicalPt(
        self: *const @This(),
        pt: gui.Point,
    ) struct { f32, f32 } {
        return .{
            self.physicalFromLogical(pt.x),
            self.physicalFromLogical(pt.y),
        };
    }

    pub fn logicalFromPhysicalPt(
        self: *const @This(),
        pt: struct { i32, i32 },
    ) gui.Point {
        return .{
            .x = self.logicalFromPhysical(pt[0]),
            .y = self.logicalFromPhysical(pt[1]),
        };
    }
};
