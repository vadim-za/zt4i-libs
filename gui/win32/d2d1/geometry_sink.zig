const std = @import("std");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");

const os = std.os.windows;

pub const FILL_MODE = enum(u32) {
    ALTERNATE = 0,
    WINDING = 1,
};

pub const PATH_SEGMENT = enum(u32) {
    NONE = 0,
    FORCE_UNSTROKED = 1,
    FORCE_ROUND_LINE_JOIN = 2,
};

pub const FIGURE_BEGIN = enum(u32) {
    FILLED = 0,
    HOLLOW = 1,
};

pub const FIGURE_END = enum(u32) {
    OPEN = 0,
    CLOSED = 1,
};

pub const ISimplifiedGeometrySink = extern struct { // ID2D1SimplifiedGeometrySink
    pub const iid = os.GUID.parse("{2cd9069e-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = com.IUnknown;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        SetFillMode__: *const fn () callconv(.winapi) void,
        SetSegmentFlags__: *const fn () callconv(.winapi) void,
        BeginFigure: *const fn (
            self: *Self,
            startPoint: d2d1.POINT_2F,
            figureBegin: FIGURE_BEGIN,
        ) callconv(.winapi) void,
        AddLines: *const fn () callconv(.winapi) void,
        AddBeziers: *const fn () callconv(.winapi) void,
        EndFigure: *const fn (
            self: *Self,
            figureEnd: FIGURE_END,
        ) callconv(.winapi) void,
        Close: *const fn (
            self: *Self,
        ) callconv(.winapi) os.HRESULT,
    };

    pub const as = com.cast;

    pub fn beginFigure(
        self: *@This(),
        start_point: *const d2d1.POINT_2F,
        figure_begin: FIGURE_BEGIN,
    ) void {
        self.vtbl.BeginFigure(self, start_point.*, figure_begin);
    }

    pub fn endFigure(
        self: *@This(),
        figure_end: FIGURE_END,
    ) void {
        self.vtbl.EndFigure(self, figure_end);
    }

    pub fn close(self: *@This()) com.Error!void {
        if (com.FAILED(self.vtbl.Close(self)))
            return com.Error.OsApi;
    }
};

pub const IGeometrySink = extern struct { // ID2D1GeometrySink
    pub const iid = os.GUID.parse("{2cd9069f-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = ISimplifiedGeometrySink;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        AddLine: *const fn (
            self: *Self,
            point: d2d1.POINT_2F,
        ) callconv(.winapi) void,
        AddBezier: *const fn (
            self: *Self,
            bezier: *const d2d1.BEZIER_SEGMENT,
        ) callconv(.winapi) void,
        AddQuadraticBezier: *const fn () callconv(.winapi) void,
        AddQuadraticBeziers: *const fn () callconv(.winapi) void,
        AddArc: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;

    pub fn addLine(self: *@This(), point: *const d2d1.POINT_2F) void {
        self.vtbl.AddLine(self, point.*);
    }

    pub fn addBezier(self: *@This(), bezier: *const d2d1.BEZIER_SEGMENT) void {
        self.vtbl.AddBezier(self, bezier);
    }
};
