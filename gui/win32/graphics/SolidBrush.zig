const std = @import("std");
const lib = @import("../../lib.zig");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const graphics = @import("../graphics.zig");
const BrushRef = graphics.BrushRef;
const Color = graphics.Color;
const DeviceResource = @import("DeviceResource.zig");

const Self = @This();

device_resource: DeviceResource = .init(@This()),
ibrush: ?*d2d1.ISolidColorBrush = null,
color: Color,

pub fn init(color: Color) @This() {
    return .{ .color = color };
}

pub fn ref(self: *const @This()) BrushRef {
    return .init(self.ibrush.?.as(d2d1.IBrush));
}

pub const virtuals = struct {
    pub fn create(
        device_resource: *DeviceResource,
        target: *d2d1.IRenderTarget,
    ) lib.Error!void {
        const self: *Self = @alignCast(@fieldParentPtr(
            "device_resource",
            device_resource,
        ));

        if (self.ibrush == null) {
            self.ibrush =
                try target.createSolidColorBrush(&.fromLib(&self.color));
        } else std.debug.assert(false);
    }

    pub fn release(device_resource: *DeviceResource) void {
        const self: *Self = @alignCast(@fieldParentPtr(
            "device_resource",
            device_resource,
        ));

        if (self.ibrush) |ibrush| {
            com.release(ibrush);
            self.ibrush = null;
        } else std.debug.assert(false);
    }
};
