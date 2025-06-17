// Device Resource Methods for Window struct
// (to be manually imported)
const Window = @import("../Window.zig");

pub fn addDeviceResource(
    self: *Window,
    ptr_to_derived_resource: anytype,
) void {
    self.device_resources.addResource(ptr_to_derived_resource);
}

pub fn removeDeviceResource(
    self: *Window,
    ptr_to_derived_resource: anytype,
) void {
    self.device_resources.removeResource(ptr_to_derived_resource);
}

pub fn removeAllDeviceResources(self: *Window) void {
    self.device_resources.removeAllResources();
}
