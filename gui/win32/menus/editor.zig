const std = @import("std");
const gui = @import("../../gui.zig");
const context = @import("context.zig");
const metadata = @import("metadata.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn AppendMenuW(
    hMenu: os.HMENU,
    uFlags: os.UINT,
    uIDNewItem: usize,
    lpNewItem: ?os.LPCWSTR,
) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub fn Editor(Command: type) type {
    return struct {
        ctx: context.Any,
        hMenu: os.HMENU,
        commands: *Commands,

        const Commands = metadata.Collection(Command);

        pub fn addCommand(
            self: *@This(),
            text: []const u8,
            id: usize,
        ) gui.Error!*Command {
            const command = try self.commands.add();
            errdefer self.commands.popLast();

            //const uItemID = self.commands.osIdOf(command);
            const uItemID = id;

            const text16 = try self.ctx.convertU8(text);
            if (AppendMenuW(
                self.hMenu,
                0,
                uItemID,
                text16,
            ) == os.FALSE) return gui.Error.OsApi;

            return command;
        }
    };
}
