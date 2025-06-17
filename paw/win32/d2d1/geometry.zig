const std = @import("std");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const os = std.os.windows;

pub const IGeometry = extern struct { // ID2D1Geometry
    pub const iid = os.GUID.parse("{2cd906a1-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = d2d1.IResource;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        GetBounds__: *const fn () callconv(.winapi) void,
        GetWidenedBounds__: *const fn () callconv(.winapi) void,
        StrokeContainsPoint__: *const fn () callconv(.winapi) void,
        FillContainsPoint__: *const fn () callconv(.winapi) void,
        CompareWithGeometry__: *const fn () callconv(.winapi) void,
        Simplify__: *const fn () callconv(.winapi) void,
        Tesselate__: *const fn () callconv(.winapi) void,
        CombineWithGeometry__: *const fn () callconv(.winapi) void,
        Outline__: *const fn () callconv(.winapi) void,
        ComputeArea__: *const fn () callconv(.winapi) void,
        ComputeLength__: *const fn () callconv(.winapi) void,
        ComputePointAtLength__: *const fn () callconv(.winapi) void,
        Widen__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;
};

pub const IPathGeometry = extern struct { // ID2D1PathGeometry
    pub const iid = os.GUID.parse("{2cd906a5-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = IGeometry;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        Open: *const fn (
            self: *Self,
            *?*d2d1.IGeometrySink,
        ) callconv(.winapi) os.HRESULT,
        Stream: *const fn () callconv(.winapi) void,
        GetSegmentCount: *const fn () callconv(.winapi) void,
        GetFigureCount: *const fn () callconv(.winapi) void,
    };

    pub fn open(self: *@This()) com.Error!*d2d1.IGeometrySink {
        var result: ?*d2d1.IGeometrySink = null;

        if (com.FAILED(self.vtbl.Open(
            self,
            &result,
        )))
            return com.Error.OsApi;

        return result orelse com.Error.OsApi;
    }
};
