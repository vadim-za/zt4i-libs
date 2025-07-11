const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const metadata = @import("metadata.zig");
const editor = @import("editor.zig");
const context = @import("context.zig");
const menus = @import("../menus.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreateMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;
extern "user32" fn SetMenu(hWnd: os.HWND, hMenu: ?os.HMENU) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub fn Bar(Command: type) type {
    return struct {
        hMenu: ?os.HMENU = null,
        commands: Commands = undefined,

        const Commands = metadata.Collection(Command);
        pub const Editor = editor.Editor(Command);

        pub fn create(
            self: *@This(),
            edit_context_ptr: anytype,
        ) gui.Error!Editor {
            if (self.hMenu != null)
                return gui.Error.Usage;

            try self.commands.init();
            errdefer self.commands.deinit();

            const hMenu: os.HMENU = CreateMenu() orelse
                return gui.Error.OsApi;
            self.hMenu = hMenu;

            return .{
                .ctx = context.Any.from(edit_context_ptr),
                .hMenu = hMenu,
                .commands = &self.commands,
            };
        }

        pub fn discard(self: *@This()) void {
            // const hMenu = self.hMenu orelse return;

            // if (DestroyMenu(hMenu) == os.FALSE and builtin.mode == .Debug)
            //     @panic("Failed to destroy menu");

            self.hMenu = null;
            self.commands.deinit();
        }

        // Quick and dirty solution. You can attach only once to a window
        // and shouldn't call attach again for the same window or menu.
        pub fn attachTo(self: *@This(), window: *gui.Window) void {
            std.debug.assert(SetMenu(window.hWnd.?, self.hMenu.?) != os.FALSE);
        }
    };
}
