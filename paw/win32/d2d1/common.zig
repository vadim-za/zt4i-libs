// dcommon.h and other headers
const std = @import("std");
const dxgi = @import("../dxgi.zig");

const os = std.os.windows;
const DXGI_FORMAT = dxgi.format.DXGI_FORMAT;

pub const SIZE_U = extern struct {
    width: u32,
    height: u32,
};

pub const POINT_2F = extern struct {
    x: os.FLOAT,
    y: os.FLOAT,
};

pub const RECT_F = extern struct {
    left: os.FLOAT,
    top: os.FLOAT,
    right: os.FLOAT,
    bottom: os.FLOAT,
};

pub const BEZIER_SEGMENT = extern struct {
    point1: POINT_2F,
    point2: POINT_2F,
    point3: POINT_2F,
};

pub const MATRIX_3X2_F = [3][2]os.FLOAT;

pub const identityMatrix = MATRIX_3X2_F{
    .{ 1, 0 },
    .{ 0, 1 },
    .{ 0, 0 },
};

pub const COLOR_F = extern struct { // D2D_COLOR_F (d2dbasetypes.h) = D3DCOLORVALUE (d3dtypes.h)
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const ALPHA_MODE = enum(u32) {
    UNKNOWN = 0,
    PREMULTIPLIED = 1,
    STRAIGHT = 2,
    IGNORE = 3,
};

pub const PIXEL_FORMAT = extern struct {
    format: DXGI_FORMAT = .UNKNOWN, // default values from d2d1helper.h
    alphaMode: ALPHA_MODE = .UNKNOWN,
};
