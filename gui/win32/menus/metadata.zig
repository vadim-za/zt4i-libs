const std = @import("std");
const gui = @import("../../gui.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

pub const CommandId = struct {
    index: usize,
};

pub const SelectedCommand = struct {
    uItemID: usize,
};

const os_item_base_id = 1;

// ----------------------------------------------------------------

pub fn Collection(CommandMetadata: type) type {
    return struct {
        entries: std.ArrayListUnmanaged(CommandMetadata) = .empty,

        pub fn deinit(self: *@This()) void {
            self.entries.deinit(gui.allocator());
        }

        pub const Command = struct {
            id: CommandId,
            meta: *CommandMetadata,
        };

        pub fn addCommand(
            self: *@This(),
        ) gui.Error!Command {
            const idx = self.entries.items.len;
            const meta = try self.entries.addOne(gui.allocator());
            return .{
                .id = .{ .index = idx },
                .meta = meta,
            };
        }

        pub fn popCommand(
            self: *@This(),
            id: CommandId,
        ) void {
            // must be the last entry
            std.debug.assert(id.index == self.entries.items.len - 1);
            self.entries.items.len -= 1;
        }

        pub fn getCommandMeta(self: *@This(), id: CommandId) *CommandMetadata {
            return &self.entries.items[id.index];
        }

        pub fn osFromId(self: *const @This(), id: CommandId) usize {
            _ = self;

            // result must fit into 31 bits
            const os_id: u31 = @intCast(os_item_base_id + id.index);
            return os_id;
        }

        pub fn idFromOs(self: *const @This(), uItemID: usize) ?CommandId {
            if (uItemID < os_item_base_id)
                return null;
            const index: usize = uItemID - os_item_base_id;
            if (index >= self.entries.items.len)
                return null;
            return .{ .index = index };
        }

        pub fn getCommandByOsId(self: *@This(), uItemID: usize) ?Command {
            const id = self.idFromOs(uItemID) orelse return null;
            return .{
                .id = id,
                .meta = self.getCommandMeta(id),
            };
        }
    };
}
