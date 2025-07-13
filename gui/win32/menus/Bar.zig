const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const Contents = @import("Contents.zig");
const Context = @import("Context.zig");
const debug = @import("../debug.zig");
const Window = @import("../Window.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreateMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;
extern "user32" fn SetMenu(hWnd: os.HWND, hMenu: ?os.HMENU) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

// window that the menu is attached to
window: ?*Window,

context: Context,
hMenu: os.HMENU,

menu_contents: Contents,

pub fn create(
    self: *@This(),
) gui.Error!void {
    try self.context.init();
    errdefer self.context.deinit();

    const hMenu: os.HMENU = CreateMenu() orelse
        return gui.Error.OsApi;

    self.hMenu = hMenu;
    self.menu_contents = .{
        .hMenu = hMenu,
        .context = &self.context,
    };
    self.window = null;
}

pub fn destroy(self: *@This()) void {
    debug.expect(self.window == null);

    if (DestroyMenu(self.hMenu) == os.FALSE)
        debug.debugModePanic("Failed to destroy menu");

    self.menu_contents.deinit();
    self.context.deinit();
}

pub fn contents(self: *@This()) *Contents {
    return &self.menu_contents;
}

pub fn attachTo(self: *@This(), window: *gui.Window) gui.Error!void {
    if (SetMenu(window.hWnd.?, self.hMenu) == os.FALSE)
        return gui.Error.OsApi;

    // Disconnect the previous menu (the user is responsible for destroying it)
    if (window.menu_bar) |menu_bar|
        menu_bar.window = null;
    window.menu_bar = self;

    self.window = window;
}

pub fn detachFrom(self: *@This(), window: *gui.Window) void {
    debug.expect(self.window == window);
    debug.expect(window.menu_bar == self);
    window.menu_bar = null;
    self.window = null;

    if (SetMenu(window.hWnd.?, null) == os.FALSE)
        debug.debugModePanic("Failed disconnecting menu from window");
}
