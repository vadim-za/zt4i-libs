const std = @import("std");
const builtin = @import("builtin");
const DeviceResource = @import("DeviceResource.zig");
const d2d1 = @import("../d2d1.zig");
const paw = @import("../../paw.zig");
const directx = @import("../directx.zig");
const com = @import("../com.zig");

const os = std.os.windows;

render_target: ?*d2d1.IHwndRenderTarget = null,
created: DeviceResource.List = .{},
uncreated: DeviceResource.List = .{},

pub fn deinit(self: *@This()) void {
    std.debug.assert(self.created.len == 0);
    std.debug.assert(self.uncreated.len == 0);
}

pub fn addResource(self: *@This(), ptr_to_derived_resource: anytype) void {
    const resource: *DeviceResource =
        &ptr_to_derived_resource.*.device_resource;

    if (resource.owner != null) {
        std.debug.assert(false);
        return;
    }

    std.debug.assert(!resource.is_created);

    self.uncreated.append(resource.node);
    resource.owner = self;
    resource.is_created = false;

    if (self.render_target) |target|
        self.createResource(resource, target);
}

pub fn removeResource(self: *@This(), ptr_to_derived_resource: anytype) void {
    const resource: *DeviceResource =
        &ptr_to_derived_resource.*.device_resource;

    if (resource.owner != self) {
        std.debug.assert(false);
        return;
    }

    if (resource.is_created)
        self.releaseResource(resource);

    std.debug.assert(!resource.is_created);
    self.uncreated.remove(resource);
    resource.owner = null;
}

fn createResource(
    self: *@This(),
    resource: *DeviceResource,
    render_target: *d2d1.IRenderTarget,
) void {
    std.debug.assert(resource.owner == self);
    std.debug.assert(!resource.is_created);

    resource.create(render_target) catch {
        if (builtin.mode == .Debug)
            @panic("Failed to create DD Resource");
        return;
    };
    self.uncreated.remove(&resource.node);
    self.created.append(&resource.node);
    resource.is_created = true;
}

fn releaseResource(
    self: *@This(),
    resource: *DeviceResource,
) void {
    std.debug.assert(resource.owner == self);
    std.debug.assert(resource.is_created);

    resource.release();
    self.created.remove(&resource.node);
    self.uncreated.append(&resource.node);
    resource.is_created = false;
}

extern "user32" fn GetClientRect(os.HWND, *os.RECT) callconv(.winapi) os.BOOL;

pub fn provideRenderTargetFor(
    self: *@This(),
    hWnd: os.HWND,
) paw.Error!*d2d1.IRenderTarget {
    if (self.render_target) |target|
        return target.as(d2d1.IRenderTarget);

    var rc: os.RECT = undefined;
    if (GetClientRect(hWnd, &rc) == os.FALSE)
        return paw.Error.OsApi;

    const size = d2d1.SIZE_U{
        .width = @intCast(rc.right - rc.left),
        .height = @intCast(rc.bottom - rc.top),
    };

    const hwnd_render_target = try directx.getD2d1Factory().createHwndRenderTarget(
        &.{},
        &.{ .hwnd = hWnd, .pixelSize = size },
    );

    self.render_target = hwnd_render_target;
    const render_target = hwnd_render_target.as(d2d1.IRenderTarget);

    var node = self.uncreated.first;
    while (node) |n| : (node = n.next) {
        const resource: *DeviceResource = .fromListNode(n);
        self.createResource(resource, render_target);
    }
    std.debug.assert(self.uncreated.first == null);

    return render_target;
}

pub fn releaseRenderTarget(
    self: *@This(),
) void {
    const render_target = self.render_target orelse return;

    com.release(render_target);
    self.render_target = null;

    var node = self.created.first;
    while (node) |n| : (node = n.next) {
        const resource: *DeviceResource = .fromListNode(n);
        self.releaseResource(resource);
    }
    std.debug.assert(self.created.first == null);
}
