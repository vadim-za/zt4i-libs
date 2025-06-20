const std = @import("std");
const d2d1 = @import("../d2d1.zig");
const BrushRef = @import("BrushRef.zig");
const Path = @import("Path.zig");
const Font = @import("Font.zig");
const unicode = @import("../unicode.zig");
const gui = @import("../../gui.zig");
const winmain = @import("../winmain.zig");

const Color = gui.Color;
const Point = gui.Point;
const Rectangle = gui.Rectangle;

target: *d2d1.IRenderTarget,
origin: Point,

pub fn drawLine(
    self: *const @This(),
    pt1: *const Point,
    pt2: *const Point,
    brush: BrushRef,
    width: f32,
) void {
    self.target.drawLine(
        &.fromGui(pt1),
        &.fromGui(pt2),
        brush.ibrush,
        width,
    );
}

pub fn drawRectangle(
    self: *const @This(),
    rect: *const Rectangle,
    brush: BrushRef,
    width: f32,
) void {
    self.target.drawRectangle(&.fromGui(rect), brush.ibrush, width);
}

pub fn fillRectangle(
    self: *const @This(),
    rect: *const Rectangle,
    brush: BrushRef,
) void {
    self.target.fillRectangle(&.fromGui(rect), brush.ibrush);
}

pub fn drawPath(
    self: *const @This(),
    path: *const Path,
    brush: BrushRef,
    width: f32,
) void {
    self.target.drawGeometry(
        path.d2d_geometry.?.as(d2d1.IGeometry),
        brush.ibrush,
        width,
    );
}

pub fn fillPath(
    self: *const @This(),
    path: *const Path,
    brush: BrushRef,
) void {
    self.target.fillGeometry(
        path.d2d_geometry.?.as(d2d1.IGeometry),
        brush.ibrush,
    );
}

pub fn clear(self: *const @This(), color: *const Color) void {
    self.target.clear(&.fromGui(color));
}

pub fn drawText(
    self: *const @This(),
    font: *const Font,
    rect: *const Rectangle,
    text: []const u8,
    brush: BrushRef,
) gui.Error!void {
    var text16: unicode.Wtf16Str(2000) = undefined;
    try text16.initU8(text);
    defer text16.deinit();

    self.target.drawText(
        text16.slice(),
        font.dwrite_text_format.?,
        &.fromGui(rect),
        brush.ibrush,
    );
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
