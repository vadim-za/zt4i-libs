// Device-dependent resource

const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const DeviceResources = @import("DeviceResources.zig");
const lib = @import("../../lib.zig");

pub const Self = @This();

vtbl: *const Vtbl,
node: List.Node = .{ .data = .{} },
owner: ?*const DeviceResources = null,
is_created: bool = false,

pub const Vtbl = struct {
    create: *const fn (
        self: *Self,
        target: *d2d1.IRenderTarget,
    ) lib.Error!void,
    release: *const fn (
        self: *Self,
    ) void,
};

pub fn init(Type: type) @This() {
    const virtuals: type = Type.virtuals;
    return .{
        .vtbl = comptime &.{
            .create = virtuals.create,
            .release = virtuals.release,
        },
    };
}

pub fn create(
    self: *Self,
    target: *d2d1.IRenderTarget,
) lib.Error!void {
    return self.vtbl.create(self, target);
}

pub fn release(
    self: *Self,
) void {
    return self.vtbl.release(self);
}

const ListData = struct {};
pub const List = std.DoublyLinkedList(ListData);

pub fn fromListNode(node: *List.Node) *@This() {
    return @alignCast(@fieldParentPtr("node", node));
}
