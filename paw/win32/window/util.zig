const std = @import("std");
const paw = @import("../../paw.zig");
const com = @import("../com.zig");
const directx = @import("../directx.zig");
const d2d1 = @import("../d2d1.zig");
const dpi = @import("../dpi.zig");

const Window = paw.Window;
const os = std.os.windows;

extern "user32" fn GetClientRect(os.HWND, *os.RECT) callconv(.winapi) os.BOOL;

pub fn getPhysicalClientRect(window: *const Window) paw.Error!os.RECT {
    if (window.hWnd) |hWnd| {
        var rc: os.RECT = undefined;
        if (GetClientRect(hWnd, &rc) != 0)
            return rc;
    }
    return paw.Error.OsApi;
}

pub fn physicalFromLogical(window: *const Window, logical_size: f32) i32 {
    return @intFromFloat(dpi.physicalFromLogical(window.dpr, logical_size));
}

pub fn logicalFromPhysical(window: *const Window, physical_size: i32) f32 {
    const float_physical_size: f32 = @floatFromInt(physical_size);
    return dpi.logicalFromPhysical(window.dpr, float_physical_size);
}

pub fn provideRenderTarget(window: *Window) paw.Error!*d2d1.IRenderTarget {
    if (window.render_target) |render_target|
        return render_target.as(d2d1.IRenderTarget);

    const hWnd = window.hWnd orelse return paw.Error.Usage;

    const rc = try getPhysicalClientRect(window);
    const size = d2d1.SIZE_U{
        .width = @intCast(rc.right - rc.left),
        .height = @intCast(rc.bottom - rc.top),
    };
    const render_target = try directx.getD2d1Factory().createHwndRenderTarget(
        &.{},
        &.{ .hwnd = hWnd, .pixelSize = size },
    );
    window.render_target = render_target;

    return render_target.as(d2d1.IRenderTarget);
}

pub fn releaseRenderTarget(window: *Window) void {
    if (window.render_target) |render_target| {
        com.release(render_target);
        window.render_target = null;
    }
}
