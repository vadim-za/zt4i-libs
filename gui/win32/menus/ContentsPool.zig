const std = @import("std");
const gui = @import("../../gui.zig");
const item_types = @import("items.zig");
const Contents = @import("Contents.zig");

pool: std.heap.MemoryPool(PoolItem),

// item_types.Item and Context have similar sizes, so we could
// use a shared pool for both
const PoolItem = union {
    item_node: item_types.ItemsList.Node,
    contents: Contents,
};

fn fieldName(T: type) []const u8 {
    return switch (T) {
        item_types.ItemsList.Node => "item_node",
        Contents => "contents",
        else => @compileError("Unsupported type " ++ @typeName(T)),
    };
}

pub fn init(self: *@This(), allocator: std.mem.Allocator) void {
    self.* = .{
        .pool = .init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.pool.deinit();
}

pub fn create(self: *@This(), T: type) gui.Error!*T {
    const pool_item = try self.pool.create();

    // This may create unnecessary code (Zig Issue #24313),
    // but it should be negligible, as the union is rather small.
    pool_item.* = @unionInit(PoolItem, fieldName(T), undefined);

    return &@field(pool_item, fieldName(T));
}

pub fn destroy(self: *@This(), ptr: anytype) void {
    const pool_item: *PoolItem = @alignCast(@fieldParentPtr(
        fieldName(@TypeOf(ptr.*)),
        ptr,
    ));

    // @alignCast is potentially needed due to Zig Issue #24359
    self.pool.destroy(@alignCast(pool_item));
}
