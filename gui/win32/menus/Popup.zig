const std = @import("std");
const lib = @import("../../lib.zig");
const item_types = @import("items.zig");
const Contents = @import("Contents.zig");
const Context = @import("Context.zig");
const debug = @import("../debug.zig");
const command_ids = @import("command_ids.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreatePopupMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;

extern "user32" fn GetCursorPos(*os.POINT) callconv(.winapi) os.BOOL;
extern "user32" fn TrackPopupMenu(
    hMenu: os.HMENU,
    uFlags: os.UINT,
    x: c_int,
    y: c_int,
    nReserved: c_int,
    hWnd: os.HWND,
    prcRect: ?*const os.RECT,
) callconv(.winapi) c_int;

pub const TPM_RIGHTBUTTON: os.UINT = 2;
pub const TPM_NONOTIFY: os.UINT = 0x80;
pub const TPM_RETURNCMD: os.UINT = 0x100;

// ----------------------------------------------------------------

context: Context,
hMenu: os.HMENU,

menu_contents: Contents,

pub fn create(
    self: *@This(),
) lib.Error!void {
    try self.context.init();
    errdefer self.context.deinit();

    const hMenu: os.HMENU = CreatePopupMenu() orelse
        return lib.Error.OsApi;

    self.hMenu = hMenu;
    self.menu_contents = .{
        .hMenu = hMenu,
        .context = &self.context,
    };
}

pub fn destroy(self: *@This()) void {
    if (DestroyMenu(self.hMenu) == os.FALSE)
        debug.debugModePanic("Failed to destroy menu");

    self.menu_contents.deinit();
    self.context.deinit();
}

pub fn contents(self: *@This()) *Contents {
    return &self.menu_contents;
}

// Returns command id.
pub fn run(
    self: *@This(),
    window: *lib.Window,
) lib.Error!?usize {
    var pt: os.POINT = undefined;
    if (GetCursorPos(&pt) == os.FALSE)
        return lib.Error.OsApi;

    const nResult = TrackPopupMenu(
        self.hMenu,
        TPM_NONOTIFY | TPM_RETURNCMD | TPM_RIGHTBUTTON,
        pt.x,
        pt.y,
        0,
        window.hWnd.?,
        null,
    );

    if (nResult > 0) {
        if (command_ids.fromOsId(@intCast(nResult))) |id|
            return id
        else
            debug.debugModePanic("Unexpected menu command ID");
    }

    // Windows API docs are not too precise on whether the last
    // error code is set to zero upon user cancelling the menu.
    // So we cannot distinguish between the zero result implying
    // a cancelled menu and an error. Thus we simply return null,
    // implying a cancelled menu.
    return null;
}
