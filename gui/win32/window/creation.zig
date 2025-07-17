const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../../gui.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const winmain = @import("../winmain.zig");
const unicode = @import("../unicode.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreateWindowExW(
    dwExStyle: os.DWORD,
    lpClassName: ?[*:0]align(1) const os.WCHAR,
    lpWindowName: ?os.LPCWSTR,
    dwStyle: os.DWORD,
    X: c_int,
    Y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: ?os.HWND,
    hMenu: ?os.HMENU,
    hInstance: ?os.HINSTANCE,
    lpParam: ?os.LPVOID,
) callconv(.winapi) ?os.HWND;

const WS_OVERLAPPED: os.DWORD = 0;
const WS_VISIBLE: os.DWORD = 0x1000_0000;
const WS_CAPTION: os.DWORD = WS_BORDER | WS_DLGFRAME;
const WS_BORDER: os.DWORD = 0x0080_0000;
const WS_DLGFRAME: os.DWORD = 0x0040_0000;
const WS_SYSMENU: os.DWORD = 0x0008_0000;
const WS_THICKFRAME: os.DWORD = 0x0004_0000;
const WS_MINIMIZEBOX: os.DWORD = 0x0002_0000;
const WS_MAXIMIZEBOX: os.DWORD = 0x0001_0000;

const WS_OVERLAPPEDWINDOW: os.DWORD =
    WS_OVERLAPPED |
    WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

extern "user32" fn SetWindowPos(
    hWnd: os.HWND,
    hWndInsertAfter: ?os.HWND,
    x: c_int,
    y: c_int,
    cx: c_int,
    cy: c_int,
    uFlags: SwpFlags,
) callconv(.winapi) os.BOOL;

const SwpFlags = packed struct(os.UINT) {
    NOSIZE: bool = false,
    NOMOVE: bool = false,
    NOZORDER: bool = false,
    _: u29 = 0,
};

extern "user32" fn AdjustWindowRectExForDpi(
    lpRect: *os.RECT,
    dwStyle: os.DWORD,
    bMenu: os.BOOL,
    dwExStyle: os.DWORD,
    dpi: os.UINT,
) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

// no resize/maximize handling yet, so can't use WS_OVERLAPPEDWINDOW
const dwCreateStyle = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
const dwCreateExStyle = 0;

pub fn createWindowRaw(title: []const u8) gui.Error!os.HWND {
    var title16: unicode.Wtf16Str(200) = undefined;
    try title16.initU8(title);
    defer title16.deinit();

    return CreateWindowExW(
        dwCreateExStyle,
        class.getClass(),
        title16.ptr(),
        dwCreateStyle,
        0,
        0,
        0,
        0,
        null,
        null,
        winmain.thisInstance(),
        null,
    ) orelse
        gui.Error.OsApi;
}

pub fn configureRawWindow(
    window: *Window,
    params: *const Window.CreateParams,
) gui.Error!void {
    if (params.menu) |bar|
        try bar.attachTo(window);

    // Compute the size after the menu is configured!
    const outer_size = try toOuterCreateSize(window, params.size);

    if (SetWindowPos(
        window.hWnd.?,
        null,
        0,
        0,
        outer_size.x,
        outer_size.y,
        .{ .NOMOVE = true, .NOZORDER = true },
    ) == 0)
        return gui.Error.OsApi;
}

fn toPhysicalSizeTrunc(
    window: *const Window,
    logical_size: gui.Point,
) os.POINT {
    const physical_size =
        window.dpr.?.physicalFromLogicalPt(logical_size);
    return .{
        .x = @intFromFloat(physical_size[0]),
        .y = @intFromFloat(physical_size[1]),
    };
}

fn toOuterCreateSize(
    window: *const Window,
    create_size: Window.Size,
) gui.Error!os.POINT {
    switch (create_size) {
        .outer => |size| return toPhysicalSizeTrunc(window, size),

        .inner => |size| {
            const physical_inner = toPhysicalSizeTrunc(window, size);

            var rc: os.RECT = .{
                .left = 0,
                .top = 0,
                .right = physical_inner.x,
                .bottom = physical_inner.y,
            };

            if (AdjustWindowRectExForDpi(
                &rc,
                dwCreateStyle,
                @intFromBool(window.menu_bar != null),
                dwCreateExStyle,
                window.dpr.?.os_dpi,
            ) == os.FALSE)
                return gui.Error.OsApi;

            return .{
                .x = rc.right - rc.left,
                .y = rc.bottom - rc.top,
            };
        },
    }
}
