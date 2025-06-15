const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const types = @import("types.zig");
const BrushRef = @import("BrushRef.zig");

const Color = types.Color;
const Point = types.Point;
const Rectangle = types.Rectangle;

target: *d2d1.IRenderTarget,
origin: Point,

pub fn clear(self: *const @This(), color: Color) void {
    self.target.clear(&color.toD2d());
}

pub fn setOrigin(self: *const @This(), new_origin: Point) Point {
    const prev_origin = self.context.origin;

    var transform = d2d1.identityMatrix();
    transform[2][0] = new_origin.x;
    transform[2][1] = new_origin.y;
    self.target.setTransform(transform);

    self.origin = new_origin;
    return prev_origin;
}

pub fn getOrigin(self: *const @This()) Point {
    return self.origin;
}

pub fn moveOriginBy(self: *const @This(), by: Point) Point {
    return self.setOrigin(self.getOrigin().movedBy(by));
}
