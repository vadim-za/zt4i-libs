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

pub fn Editor(CommandMetadata: type) type {
    return struct {
        ctx: context.Any,
        hMenu: os.HMENU,
        root_meta: *RootMeta,

        const RootMeta = metadata.Collection(CommandMetadata);

        pub const Command = RootMeta.Command;

        pub fn addCommand(
            self: *@This(),
            text: []const u8,
        ) gui.Error!Command {
            const command = try self.root_meta.addCommand();
            errdefer self.root_meta.popCommand(command.id);

            const uItemID = self.root_meta.osFromId(command.id);

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
