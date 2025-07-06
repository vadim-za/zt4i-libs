const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const metadata = @import("metadata.zig");
const editor = @import("editor.zig");
const context = @import("context.zig");
const menus = @import("../menus.zig");

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

pub fn Popup(CommandMetadata: type) type {
    return struct {
        hMenu: ?os.HMENU = null,
        metadata: RootMetadata = undefined,

        const RootMetadata = metadata.Collection(CommandMetadata);
        pub const Command = RootMetadata.Command;
        pub const Editor = editor.Editor(CommandMetadata);

        pub fn create(
            self: *@This(),
            edit_context_ptr: anytype,
        ) gui.Error!Editor {
            if (self.hMenu != null)
                return gui.Error.Usage;

            const hMenu = CreatePopupMenu() orelse
                return gui.Error.OsApi;

            self.hMenu = hMenu;
            self.metadata = .{};

            return .{
                .ctx = context.Any.from(edit_context_ptr),
                .hMenu = hMenu,
                .root_meta = &self.metadata,
            };
        }

        pub fn destroy(self: *@This()) void {
            const hMenu = self.hMenu orelse return;

            if (DestroyMenu(hMenu) == os.FALSE and builtin.mode == .Debug)
                @panic("Failed to destroy menu");

            self.hMenu = null;
            self.metadata.deinit();
        }

        pub fn runWithinWindow(
            self: *@This(),
            window: *gui.Window,
        ) gui.Error!?Command {
            var pt: os.POINT = undefined;
            if (GetCursorPos(&pt) == os.FALSE)
                return gui.Error.OsApi;

            const nResult = TrackPopupMenu(
                self.hMenu.?,
                TPM_NONOTIFY | TPM_RETURNCMD | TPM_RIGHTBUTTON,
                pt.x,
                pt.y,
                0,
                window.hWnd.?,
                null,
            );

            if (nResult > 0)
                return self.metadata.getCommandByOsId(@intCast(nResult));

            // Windows API docs are not too precise on whether the last
            // error code is set to zero upon user cancelling the menu.
            // So we cannot distinguish between the zero result implying
            // a cancelled menu and an error. Thus we simply return null,
            // implying a cancelled menu.
            return null;
        }
    };
}
