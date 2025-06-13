const std = @import("std");
const os = std.os.windows;

const paw = @import("../paw.zig");
const class = @import("window/class.zig");
const responders = @import("window/responders.zig");
const Responders = responders.Responders;
const thisInstance = @import("winmain.zig").thisInstance;
const dpi = @import("dpi.zig");
const Wtf16Str = @import("Wtf16Str.zig");
const wnd_proc = @import("window/wnd_proc.zig");

hWnd: ?os.HWND = null,
dpr: f32 = 1,

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
    uFlags: os.UINT,
) callconv(.winapi) os.BOOL;

const SWP_NOSIZE: os.UINT = 1;
const SWP_NOMOVE: os.UINT = 2;
const SWP_NOZORDER: os.UINT = 4;

extern "user32" fn DestroyWindow(
    hWnd: os.HWND,
) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub fn create(
    Impl: type,
    impl: *Impl,
    title: []const u8,
    comptime resps: Responders(Impl),
    width: f32,
    height: f32,
) paw.Error!void {
    const window = resps.getCore(impl);
    if (window.hWnd != null)
        return paw.Error.Usage; // window already exists

    const title16: Wtf16Str = try .initU8(title);
    defer title16.deinit();

    const hWnd = CreateWindowExW(
        0,
        class.getClass(),
        title16.ptr(),
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        0,
        0,
        0,
        0,
        null,
        null,
        thisInstance(),
        null,
    ) orelse
        return paw.Error.OsApi;
    errdefer _ = DestroyWindow(hWnd);

    const dpr = dpi.getDprFor(hWnd);

    const physical_width: i32 =
        @intFromFloat(dpi.physicalFromLogical(dpr, width));
    const physical_height: i32 =
        @intFromFloat(dpi.physicalFromLogical(dpr, height));
    if (SetWindowPos(
        hWnd,
        null,
        0,
        0,
        physical_width,
        physical_height,
        SWP_NOMOVE | SWP_NOZORDER,
    ) == 0)
        return paw.Error.OsApi;

    window.* = .{
        .hWnd = hWnd,
        .dpr = dpr,
    };

    class.subclass(hWnd, wnd_proc.make(Impl, resps), impl);
}

pub fn destroy(window: *@This()) paw.Error!void {
    const h = window.hWnd orelse
        return paw.Error.Usage; // window is null

    if (DestroyWindow(h) == 0)
        return paw.Error.OsApi;
}

// --------------------------------------------------------------

comptime {
    std.testing.refAllDecls(responders);
}
