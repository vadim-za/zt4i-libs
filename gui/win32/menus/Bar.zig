const std = @import("std");
const builtin = @import("builtin");
const lib = @import("../../lib.zig");
const Contents = @import("Contents.zig");
const Context = @import("Context.zig");
const debug = @import("../debug.zig");
const Window = @import("../Window.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreateMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;
extern "user32" fn DrawMenuBar(hWnd: os.HWND) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

// Window that the menu is attached to.
// Attaching and detaching is done by the window.
window: ?*Window,

context: Context,
hMenu: os.HMENU,

menu_contents: Contents,

pub fn create(
    self: *@This(),
) lib.Error!void {
    try self.context.init();
    errdefer self.context.deinit();

    const hMenu: os.HMENU = CreateMenu() orelse
        return lib.Error.OsApi;

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

/// You must call this function after doing top-level modifications
/// to a menu bar attached to a window. It's also okay to call this
/// function if the menu has been created but is not attached to a
/// window.
pub fn update(self: *@This()) void {
    if (self.window) |window| {
        if (DrawMenuBar(window.hWnd.?) == os.FALSE)
            debug.debugModePanic("Failed to draw menu bar");
    }
}
