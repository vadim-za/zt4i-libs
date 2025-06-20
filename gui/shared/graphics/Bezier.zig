const std = @import("std");
const Point = @import("Point.zig");
const Rectangle = @import("Rectangle.zig");

pt: [4]Point,

pub fn initHermite(p0: Point, v0: Point, p1: Point, v1: Point) @This() {
    const vscale = 1.0 / 3.0;

    return .{ .pt = .{
        p0,
        .{ .x = p0.x + v0.x * vscale, .y = p0.y + v0.y * vscale },
        .{ .x = p1.x - v1.x * vscale, .y = p1.y - v1.y * vscale },
        p1,
    } };
}

pub fn at(self: *const @This(), t: f32) Point {
    const t2 = t * t;
    const t3 = t2 * t;
    const ct = 1 - t;
    const ct2 = ct * ct;
    const ct3 = ct2 * ct;
    const weights: [4]f32 = .{ ct3, 3 * ct2 * t, 3 * ct * t2, t3 };

    var result = Point{ .x = 0, .y = 0 };
    for (&self.pt, &weights) |p, w| {
        result.x += p.x * w;
        result.y += p.y * w;
    }

    return result;
}

pub fn derivativeAt(self: *const @This(), t: f32) Point {
    const t2 = t * t;
    const ct = 1 - t;
    const ct2 = ct * ct;
    const weights: [3]f32 = .{ 3 * ct2, 6 * ct * t, 3 * t2 };

    var result = Point{ .x = 0, .y = 0 };
    for (&weights, 0..) |w, i| {
        result.x += (self.pt[i + 1].x - self.pt[i].x) * w;
        result.y += (self.pt[i + 1].y - self.pt[i].y) * w;
    }

    return result;
}

pub fn boundingRect(self: *const @This()) Rectangle {
    var result = Rectangle{
        .left = self.pt[0].x,
        .top = self.pt[0].y,
        .right = self.pt[0].x,
        .bottom = self.pt[0].y,
    };

    for (self.pt[1..]) |p| {
        result.left = @min(result.left, p.x);
        result.top = @min(result.top, p.y);
        result.right = @max(result.right, p.x);
        result.bottom = @max(result.bottom, p.y);
    }

    return result;
}

pub fn segment(self: *const @This(), t0: f32, t1: f32) @This() {
    const p0 = self.at(t0);
    const p1 = self.at(t1);

    const v0 = self.derivativeAt(t0);
    const v1 = self.derivativeAt(t1);

    const vscale = (t1 - t0) / 3;

    return .{ .pt = .{
        p0,
        .{ .x = p0.x + v0.x * vscale, .y = p0.y + v0.y * vscale },
        .{ .x = p1.x - v1.x * vscale, .y = p1.y - v1.y * vscale },
        p1,
    } };
}

pub fn hit(self: *const @This(), p: Point, abs_tolerance: f32) ?f32 {
    const rect = self.boundingRect();

    if (rect.grownBy(.{ .x = abs_tolerance, .y = abs_tolerance }).hit(p)) {
        if (rect.diag() < 0.5 * abs_tolerance)
            return 0.5;

        if (self.segment(0, 0.5).hit(p, abs_tolerance)) |tau| {
            return std.math.lerp(0, 0.5, tau);
        } else if (self.segment(0.5, 1).hit(p, abs_tolerance)) |tau| {
            return std.math.lerp(0.5, 1, tau);
        } else return null;
    } else return null;
}
