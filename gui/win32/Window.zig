const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../gui.zig");
const class = @import("window/class.zig");
const responders = @import("window/responders.zig");
const winmain = @import("winmain.zig");
const dpi = @import("dpi.zig");
const unicode = @import("unicode.zig");
const wndproc = @import("window/wndproc.zig");
const d2d1 = @import("d2d1.zig");
const DeviceResources = @import("graphics/DeviceResources.zig");
const menus = @import("menus.zig");
const debug = @import("debug.zig");

const os = std.os.windows;

pub const Responders = responders.Responders;

hWnd: ?os.HWND = null,
dpr: ?dpi.Dpr = null,
device_resources: DeviceResources = .{},
menu_bar: ?*menus.Bar = null,

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

extern "user32" fn DestroyWindow(hWnd: os.HWND) callconv(.winapi) os.BOOL;
extern "user32" fn UpdateWindow(hWnd: os.HWND) callconv(.winapi) os.BOOL;
extern "user32" fn ShowWindow(
    hWnd: os.HWND,
    nCmdShow: CmdShow,
) callconv(.winapi) os.BOOL;

const CmdShow = enum(c_int) {
    HIDE = 0,
    SHOWNORMAL = 1,
    SHOWMINIMIZED = 2,
    SHOWMAXIMIZED = 3,
    SHOWNOACTIVATE = 4,
    SHOW = 5,
    MINIMIZE = 6,
    SHOWMINNOACTIVATE = 7,
    SHOWNA = 8,
    RESTORE = 9,
    SHOWDEFAULT = 10,
    FORCEMINIMIZE = 11,

    const NORMAL = .SHOWNORMAL;
    const MAXIMIZE = .SHOWMAXIMIZED;
    const MAX = .FORCEMINIMIZE;
};

extern "user32" fn AdjustWindowRectExForDpi(
    lpRect: *os.RECT,
    dwStyle: os.DWORD,
    bMenu: os.BOOL,
    dwExStyle: os.DWORD,
    dpi: os.UINT,
) callconv(.winapi) os.BOOL;

extern "user32" fn InvalidateRect(
    os.HWND,
    ?*const os.RECT,
    bErase: os.BOOL,
) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub fn deinit(self: *@This()) void {
    self.device_resources.deinit();
}

pub const Size = union(enum) {
    outer: gui.Point,
    inner: gui.Point,
};

pub const CreateParams = struct {
    title: []const u8,
    size: Size,

    /// The caller still owns the menu, but the menu becomes attached
    /// to the window and shouldn't be destroyed prior to the window
    /// destruction (or a failed creation of the window).
    menu: ?*menus.Bar,
};

pub fn create(
    Impl: type,
    impl: *Impl,
    comptime resps: Responders(Impl),
    params: CreateParams,
    on_create: anytype,
) gui.Error!void {
    const window = resps.getCore(impl);
    if (window.hWnd != null)
        return gui.Error.Usage; // window already exists

    const hWnd = try createWindowRaw(params.title);
    window.hWnd = hWnd;
    window.dpr = .fromWindow(hWnd);

    {
        // This errdefer is correct only until we subclass the window,
        // so put it inside a block.
        errdefer {
            _ = DestroyWindow(hWnd);
            window.hWnd = null;
            window.dpr = null;
        }

        try window.configureRawWindow(&params);

        // TODO: change after Issue #4625 is addressed
        switch (comptime on_create.len) {
            0 => {},
            // The return type of on_create[0] must match the one
            // of Window.create, or at least be compatible to it.
            2 => try @call(.auto, on_create[0], on_create[1]),
            else => @compileError("Wrong 'on_create' argument"),
        }
    }

    class.subclass(hWnd, wndproc.make(Impl, resps), impl);

    _ = ShowWindow(hWnd, .SHOW); // return value does not matter
    _ = UpdateWindow(hWnd); // ignore return value
}

fn configureRawWindow(
    self: *@This(),
    params: *const CreateParams,
) gui.Error!void {
    if (params.menu) |bar|
        try bar.attachTo(self);

    // Compute the size after the menu is configured!
    const outer_size = try self.toOuterCreateSize(params.size);

    if (SetWindowPos(
        self.hWnd.?,
        null,
        0,
        0,
        outer_size.x,
        outer_size.y,
        .{ .NOMOVE = true, .NOZORDER = true },
    ) == 0)
        return gui.Error.OsApi;
}

// no resize/maximize handling yet, so can't use WS_OVERLAPPEDWINDOW
const dwCreateStyle = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
const dwCreateExStyle = 0;

fn createWindowRaw(title: []const u8) gui.Error!os.HWND {
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

pub fn destroy(self: *@This()) void {
    const hWnd = self.hWnd orelse return;

    if (DestroyWindow(hWnd) == os.FALSE)
        debug.debugModePanic("Window destruction error");
}

pub fn redraw(self: *@This(), now: bool) void {
    if (self.hWnd) |hWnd| {
        _ = InvalidateRect(hWnd, null, os.FALSE);
        if (now)
            _ = UpdateWindow(hWnd);
    }
}

const dr_methods = @import("window/device_resource_methods.zig");
pub const addDeviceResource = dr_methods.addDeviceResource;
pub const removeDeviceResource = dr_methods.removeDeviceResource;
pub const removeAllDeviceResources = dr_methods.removeAllDeviceResources;

fn toPhysicalSizeTrunc(
    self: *const @This(),
    logical_size: gui.Point,
) os.POINT {
    const physical_size = self.dpr.?.physicalFromLogicalPt(logical_size);
    return .{
        .x = @intFromFloat(physical_size[0]),
        .y = @intFromFloat(physical_size[1]),
    };
}

fn toOuterCreateSize(
    self: *const @This(),
    create_size: Size,
) gui.Error!os.POINT {
    switch (create_size) {
        .outer => |size| return self.toPhysicalSizeTrunc(size),

        .inner => |size| {
            const physical_inner = self.toPhysicalSizeTrunc(size);

            var rc: os.RECT = .{
                .left = 0,
                .top = 0,
                .right = physical_inner.x,
                .bottom = physical_inner.y,
            };

            if (AdjustWindowRectExForDpi(
                &rc,
                dwCreateStyle,
                @intFromBool(self.menu_bar != null),
                dwCreateExStyle,
                self.dpr.?.os_dpi,
            ) == os.FALSE)
                return gui.Error.OsApi;

            return .{
                .x = rc.right - rc.left,
                .y = rc.bottom - rc.top,
            };
        },
    }
}

// --------------------------------------------------------------

comptime {
    std.testing.refAllDecls(responders);
}
