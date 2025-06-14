const std = @import("std");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const os = std.os.windows;

pub const IResource = extern struct { // ID2D1Resource
    pub const iid = os.GUID.parse("{2cd906a1-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = com.IUnknown;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        GetFactory__: *const fn () callconv(.winapi) void,
    };
};
