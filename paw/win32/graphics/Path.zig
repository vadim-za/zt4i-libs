const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const com = @import("../com.zig");
const graphics = @import("../graphics.zig");
const directx = @import("../directx.zig");
const Point = graphics.Point;
const Bezier = graphics.Bezier;
const paw = @import("../../paw.zig");

const Self = @This();

d2d_geometry: *d2d1.IPathGeometry,

pub const Mode = enum {
    open,
    closed,
};

pub fn deinit(self: @This()) void {
    self.d2d_geometry.releaseInterface();
}

pub fn begin(mode: Mode, at: *const Point) paw.Error!Sink {
    const d2d_factory = directx.getD2d1Factory();
    const geometry = try d2d_factory.createPathGeometry();
    errdefer com.release(geometry);

    const sink = try geometry.open();
    errdefer com.release(sink);

    sink.beginFigure(
        at.toD2d(),
        switch (mode) {
            .open => .HOLLOW,
            .closed => .FILLED,
        },
    );

    return .{
        .d2d_geometry = geometry,
        .d2d_sink = sink,
        .mode = mode,
        .is_open = true,
    };
}

pub const Sink = struct {
    d2d_geometry: *d2d1.IPathGeometry,
    d2d_sink: d2d1.IGeometrySink,
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

    pub fn close(self: *@This()) paw.Error!Self {
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
        for (points[1..]) |*p|
            self.addLine(p.toD2d());
    }

    pub fn addBeziers(self: *@This(), segments: []const BezierTo) void {
        // TODO: use ISimplifiedGeometrySink.AddBeziers
        for (segments) |*seg|
            self.addBezier(&.{
                .point1 = seg.c_from.toD2d(),
                .point2 = seg.c_to.toD2d(),
                .point3 = seg.to.toD2d(),
            });
    }
};

pub const BezierTo = struct {
    to: Point,
    c_from: Point,
    c_to: Point,
    pub fn init(seg: Bezier) @This() {
        return .{ .to = seg.pt[3], .c_from = seg.pt[1], .c_to = seg.pt[2] };
    }
};
