const std = @import("std");
const builtin = @import("builtin");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const os = std.os.windows;

pub const IFactory = extern struct { // ID2D1Factory
    pub const iid = os.GUID.parse("{06152247-6f50-465a-9245-118bfd3b6007}");
    pub const @".Base" = com.IUnknown;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        ReloadSystemMetrics__: *const fn () callconv(.winapi) void,
        GetDesktopDpi__: *const fn () callconv(.winapi) void,
        CreateRectangleGeometry__: *const fn () callconv(.winapi) void,
        CreateRoundedRectangleGeometry__: *const fn () callconv(.winapi) void,
        CreateEllipseGeometry__: *const fn () callconv(.winapi) void,
        CreateGeometryGroup__: *const fn () callconv(.winapi) void,
        CreateTransformedGeometry__: *const fn () callconv(.winapi) void,
        CreatePathGeometry__: *const fn () callconv(.winapi) void,
        CreateStrokeStyle__: *const fn () callconv(.winapi) void,
        CreateDrawingStateBlock__: *const fn () callconv(.winapi) void,
        CreateWicBitmapRenderTarget__: *const fn () callconv(.winapi) void,
        CreateHwndRenderTarget: *const fn (
            self: *Self,
            renderTargetProperties: *const d2d1.RENDER_TARGET_PROPERTIES,
            hwndRenderTargetProperties: *const d2d1.HWND_RENDER_TARGET_PROPERTIES,
            hwndRenderTarget: *?*d2d1.IHwndRenderTarget,
        ) callconv(.winapi) os.HRESULT,
        CreateDxgiSurfaceRenderTarget__: *const fn () callconv(.winapi) void,
        CreateDCRenderTarget__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;

    pub fn createHwndRenderTarget(
        self: *@This(),
        render_target_properties: *const d2d1.RENDER_TARGET_PROPERTIES,
        hwnd_render_target_properties: *const d2d1.HWND_RENDER_TARGET_PROPERTIES,
    ) com.Error!*d2d1.IHwndRenderTarget {
        var result: ?*d2d1.IHwndRenderTarget = null;

        if (com.FAILED(self.vtbl.CreateHwndRenderTarget(
            self,
            render_target_properties,
            hwnd_render_target_properties,
            &result,
        )))
            return com.Error.OsApi;

        return result orelse com.Error.OsApi;
    }
};

pub const FACTORY_TYPE = enum(u32) {
    SINGLE_THREADED = 0,
    MULTI_THREADED = 1,
};

pub const FACTORY_OPTIONS = extern struct {
    debugLevel: DEBUG_LEVEL,
};

pub const DEBUG_LEVEL = enum(u32) {
    NONE = 0,
    ERROR = 1,
    WARNING = 2,
    INFORMATION = 3,
};

extern "d2d1" fn D2D1CreateFactory(
    factoryType: FACTORY_TYPE,
    riid: com.REFIID,
    pFactoryOptions: ?*const FACTORY_OPTIONS,
    ppIFactory: *?*anyopaque,
) callconv(.winapi) os.HRESULT;

pub fn createFactory(
    IType: type,
    factoryType: FACTORY_TYPE,
) com.Error!*IType {
    var result: ?*IType = null;

    if (com.FAILED(D2D1CreateFactory(
        factoryType,
        &IType.iid,
        if (builtin.mode == .Debug)
            &.{ .debugLevel = .ERROR }
        else
            null,
        @ptrCast(&result),
    )))
        return com.Error.OsApi;

    return result orelse com.Error.OsApi;
}
