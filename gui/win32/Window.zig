const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../gui.zig");
const class = @import("window/class.zig");
const creation = @import("window/creation.zig");
const responders = @import("window/responders.zig");
const dpi = @import("dpi.zig");
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

    const hWnd = try creation.createWindowRaw(params.title);
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

        try creation.configureRawWindow(window, &params);

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

// --------------------------------------------------------------

comptime {
    std.testing.refAllDecls(responders);
}
