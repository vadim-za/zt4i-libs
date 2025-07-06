const std = @import("std");
const gui = @import("../../gui.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

// pub const SelectedCommand = struct {
//     uItemID: usize,
// };

const os_item_base_id = 1;

// ----------------------------------------------------------------

pub fn Collection(Command: type) type {
    return struct {
        entry_index: std.ArrayListUnmanaged(*Entry) = .empty,
        entry_pool: std.heap.MemoryPool(Entry),

        pub fn init(self: *@This()) gui.Error!void {
            self.* = .{
                .entry_pool = .init(gui.allocator()),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.entry_index.deinit(gui.allocator());
            self.entry_pool.deinit();
        }

        // The MemoryPool may potentially overalign item pointers in its API.
        // This might have required the use of @alignCast with MemoryPool.destroy(),
        // but this won't happen here, since Entry contains a 'usize' field
        // and thereby its alignment is at least as large as the one of the
        // internal Node type of the MemoryPool (in the current Zig's std).
        const Entry = struct {
            pos: usize,
            command: Command,
        };

        fn posOf(
            self: *const @This(),
            command: *const Command,
        ) usize {
            const entry: *const Entry =
                @alignCast(@fieldParentPtr("command", command));

            const pos = entry.pos;

            // A failing assertion indicates a wrong 'commmand' pointer
            std.debug.assert(pos < self.entry_index.items.len and
                entry == self.entry_index.items[pos]);

            return pos;
        }

        pub fn add(
            self: *@This(),
        ) gui.Error!*Command {
            const entry = try self.entry_pool.create();
            errdefer self.entry_pool.destroy(entry);

            const pos = self.entry_index.items.len;
            try self.entry_index.append(gui.allocator(), entry);

            entry.pos = pos;
            return &entry.command;
        }

        pub fn popLast(
            self: *@This(),
        ) void {
            const last_pos = self.entry_index.items.len - 1;
            const last_entry = self.entry_index.items[last_pos];
            self.entry_index.items.len -= 1;
            self.entry_pool.destroy(last_entry);
        }

        pub fn osIdOf(self: *const @This(), command: *const Command) usize {
            const pos = self.posOf(command);

            // result must fit into 31 bits
            const os_id: u31 = @intCast(os_item_base_id + pos);
            return os_id;
        }

        pub fn commandFromOsId(self: *const @This(), uItemID: usize) ?*Command {
            if (uItemID < os_item_base_id)
                return null;

            const pos: usize = uItemID - os_item_base_id;
            if (pos >= self.entry_index.items.len)
                return null;

            return &self.entry_index.items[pos].command;
        }
    };
}
