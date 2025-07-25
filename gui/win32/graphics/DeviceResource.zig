// Device-dependent resource

const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const DeviceResources = @import("DeviceResources.zig");
const lib = @import("../../lib.zig");
const lib_imports = @import("../../lib_imports.zig");
const cc = lib_imports.cc;

pub const Self = @This();

vtbl: *const Vtbl,
list_hook: List.Hook = .{},
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

pub const List = cc.List(@This(), .{
    .implementation = .{ .double_linked = .null_terminated },
    .hook_field = "list_hook",
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
