const std = @import("std");

const use_dbga = std.debug.runtime_safety;

dbga: if (use_dbga) std.heap.DebugAllocator(.{}) else void,

// init() function is supposed to return an error union.
// Since this one cannot fail, we use an empty error set.
pub fn init(self: *@This()) error{}!void {
    if (use_dbga)
        self.dbga = .{};
}

pub fn deinit(self: *@This()) void {
    if (use_dbga) {
        switch (self.dbga.deinit()) {
            .ok => {},
            .leak => @panic("Memory leak detected"),
        }
    }
}

pub fn allocator(self: *@This()) std.mem.Allocator {
    return if (use_dbga)
        self.dbga.allocator()
    else
        std.heap.smp_allocator;
}
