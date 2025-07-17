const std = @import("std");

const lib = @import("../../lib.zig");
const Window = @import("../Window.zig");
const menus = @import("../menus.zig");
const debug = @import("../debug.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn SetMenu(hWnd: os.HWND, hMenu: ?os.HMENU) callconv(.winapi) os.BOOL;
extern "user32" fn DrawMenuBar(hWnd: os.HWND) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub fn attach(
    window: *Window,
    bar: *menus.Bar,
) lib.Error!void {
    debug.expect(bar.window == null);
    debug.expect(window.menu_bar == null);

    if (SetMenu(window.hWnd.?, bar.hMenu) == os.FALSE)
        return lib.Error.OsApi;

    window.menu_bar = bar;
    bar.window = window;
}

pub fn detach(window: *lib.Window, bar: *menus.Bar) void {
    debug.expect(bar.window == window);
    debug.expect(window.menu_bar == bar);
    window.menu_bar = null;
    bar.window = null;

    if (SetMenu(window.hWnd.?, null) == os.FALSE)
        debug.debugModePanic("Failed disconnecting menu from window");
}
