const std = @import("std");
const builtin = @import("builtin");
const DeviceResource = @import("DeviceResource.zig");
const d2d1 = @import("../d2d1.zig");
const lib = @import("../../lib.zig");
const directx = @import("../directx.zig");
const com = @import("../com.zig");

const os = std.os.windows;

render_target: ?*d2d1.IHwndRenderTarget = null,
created: DeviceResource.List = .{},
uncreated: DeviceResource.List = .{},

pub fn deinit(self: *@This()) void {
    std.debug.assert(!self.created.hasContent());
    std.debug.assert(!self.uncreated.hasContent());
}

pub fn addResource(self: *@This(), ptr_to_derived_resource: anytype) void {
    const resource: *DeviceResource =
        &ptr_to_derived_resource.*.device_resource;

    self.addDeviceResource(resource);
}

pub fn removeResource(self: *@This(), ptr_to_derived_resource: anytype) void {
    const resource: *DeviceResource =
        &ptr_to_derived_resource.*.device_resource;

    self.removeDeviceResource(resource);
}

fn addDeviceResource(self: *@This(), resource: *DeviceResource) void {
    if (resource.owner != null) {
        std.debug.assert(false);
        return;
    }

    std.debug.assert(!resource.is_created);

    self.uncreated.insertLast(resource);
    resource.owner = self;
    resource.is_created = false;

    if (self.render_target) |render_target| {
        self.createDeviceResource(
            resource,
            render_target.as(d2d1.IRenderTarget),
        ) catch {}; // ignore error, will try to create again on next paint
    }
}

fn removeDeviceResource(
    self: *@This(),
    resource: *DeviceResource,
) void {
    if (resource.owner != self) {
        std.debug.assert(false);
        return;
    }

    if (resource.is_created)
        self.releaseDeviceResource(resource);

    std.debug.assert(!resource.is_created);
    self.uncreated.remove(resource);
    resource.owner = null;
}

pub fn removeAllResources(self: *@This()) void {
    while (self.created.last()) |resource|
        self.removeDeviceResource(resource);
    while (self.uncreated.last()) |resource|
        self.removeDeviceResource(resource);
}

fn createDeviceResource(
    self: *@This(),
    resource: *DeviceResource,
    render_target: *d2d1.IRenderTarget,
) lib.Error!void {
    std.debug.assert(resource.owner == self);
    std.debug.assert(!resource.is_created);

    try resource.create(render_target);
    self.uncreated.remove(resource);
    self.created.insertLast(resource);
    resource.is_created = true;
}

fn releaseDeviceResource(
    self: *@This(),
    resource: *DeviceResource,
) void {
    std.debug.assert(resource.owner == self);
    std.debug.assert(resource.is_created);

    resource.release();
    self.created.remove(resource);
    self.uncreated.insertLast(resource);
    resource.is_created = false;
}

extern "user32" fn GetClientRect(os.HWND, *os.RECT) callconv(.winapi) os.BOOL;

fn provideRenderTargetFor(
    self: *@This(),
    hWnd: os.HWND,
) lib.Error!*d2d1.IHwndRenderTarget {
    if (self.render_target) |render_target|
        return render_target;

    var rc: os.RECT = undefined;
    if (GetClientRect(hWnd, &rc) == os.FALSE)
        return lib.Error.OsApi;

    const size = d2d1.SIZE_U{
        .width = @intCast(rc.right - rc.left),
        .height = @intCast(rc.bottom - rc.top),
    };

    const render_target = try directx.getD2d1Factory().createHwndRenderTarget(
        &.{},
        &.{ .hwnd = hWnd, .pixelSize = size },
    );

    self.render_target = render_target;
    return render_target;
}

pub fn provideResourcesFor(
    self: *@This(),
    hWnd: os.HWND,
) lib.Error!*d2d1.IHwndRenderTarget {
    const hwnd_target = try self.provideRenderTargetFor(hWnd);
    const target = hwnd_target.as(d2d1.IRenderTarget);

    while (self.uncreated.first()) |resource|
        try self.createDeviceResource(resource, target);
    std.debug.assert(!self.uncreated.hasContent());

    return hwnd_target;
}

pub fn releaseResources(
    self: *@This(),
) void {
    if (self.render_target) |render_target| {
        com.release(render_target);
        self.render_target = null;
    }

    while (self.created.first()) |resource|
        self.releaseDeviceResource(resource);
    std.debug.assert(!self.created.hasContent());
}
