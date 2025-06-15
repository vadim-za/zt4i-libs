const std = @import("std");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const os = std.os.windows;

pub const BRUSH_PROPERTIES = extern struct {
    opacity: os.FLOAT,
    transform: d2d1.MATRIX_3X2_F,
};

pub const IBrush = extern struct { // ID2D1Brush
    pub const iid = os.GUID.parse("{2cd906a8-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = d2d1.IResource;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        SetOpacity__: *const fn () callconv(.winapi) void,
        SetTransform__: *const fn () callconv(.winapi) void,
        GetOpacity__: *const fn () callconv(.winapi) void,
        GetTransform__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;
};

pub const ISolidColorBrush = extern struct { // ID2D1SolidColorBrush
    pub const iid = os.GUID.parse("{2cd906a9-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = d2d1.IBrush;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        SetColor__: *const fn () callconv(.winapi) void,
        GetColor__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;
};
