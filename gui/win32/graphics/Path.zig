const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const com = @import("../com.zig");
const graphics = @import("../graphics.zig");
const directx = @import("../directx.zig");
const Point = graphics.Point;
const Bezier = graphics.Bezier;
const gui = @import("../../gui.zig");

const Self = @This();

d2d_geometry: ?*d2d1.IPathGeometry = null,

pub const Mode = enum {
    open,
    closed,
};

pub fn deinit(self: *@This()) void {
    if (self.d2d_geometry) |geometry| {
        com.release(geometry);
        self.d2d_geometry = null;
    }
}

pub fn begin(mode: Mode, at: *const Point) gui.Error!Sink {
    const d2d_factory = directx.getD2d1Factory();
    const d2d_geometry = try d2d_factory.createPathGeometry();
    errdefer com.release(d2d_geometry);

    const d2d_geometry_sink = try d2d_geometry.open();
    errdefer com.release(d2d_geometry_sink);

    const d2d_sink = d2d_geometry_sink.as(d2d1.ISimplifiedGeometrySink);

    d2d_sink.beginFigure(
        &.fromGui(at),
        switch (mode) {
            .open => .HOLLOW,
            .closed => .FILLED,
        },
    );

    return .{
        .d2d_geometry = d2d_geometry,
        .d2d_sink = d2d_geometry_sink,
        .mode = mode,
        .is_open = true,
    };
}

pub const Sink = struct {
    d2d_geometry: *d2d1.IPathGeometry,
    d2d_sink: *d2d1.IGeometrySink,
    mode: Mode,
    is_open: bool,

    pub fn abort(self: *@This()) void {
        // Should not be called after the Sink has been closed!
        if (!self.is_open) {
            std.debug.assert(false);
            return;
        }

        // A failing close would have released the interfaces,
        // so return.
        self.close() catch return;

        com.release(self.d2d_sink);
        com.release(self.d2d_geometry);
    }

    pub fn close(self: *@This()) gui.Error!Self {
        std.debug.assert(self.is_open);
        self.is_open = false;

        errdefer com.release(self.d2d_geometry);
        errdefer com.release(self.d2d_sink);

        const sink = self.d2d_sink.as(d2d1.ISimplifiedGeometrySink);
        sink.endFigure(
            switch (self.mode) {
                .open => .OPEN,
                .closed => .CLOSED,
            },
        );

        try sink.close();
        com.release(self.d2d_sink);
        // No errors may be returned from this point on,
        // otherwise deferred sink release will be invoked again.

        return .{ .d2d_geometry = self.d2d_geometry };
    }

    pub fn addLines(self: *@This(), points: []const Point) void {
        // TODO: use ISimplifiedGeometrySink.AddLines
        for (points) |*p|
            self.d2d_sink.addLine(&.fromGui(p));
    }

    pub fn addBeziers(self: *@This(), segments: []const BezierTo) void {
        // TODO: use ISimplifiedGeometrySink.AddBeziers
        for (segments) |*seg|
            self.d2d_sink.addBezier(&.{
                .point1 = .fromGui(&seg.c_from),
                .point2 = .fromGui(&seg.c_to),
                .point3 = .fromGui(&seg.to),
            });
    }
};

pub const BezierTo = struct {
    to: Point,
    c_from: Point, // control point at current point
    c_to: Point, // cotrol point at 'to'
};
