const std = @import("std");
const d2d1 = @import("../../d2d1.zig");
const Point = @import("Point.zig");

left: f32,
top: f32,
right: f32,
bottom: f32,

pub fn initCorners(lt: *const Point, rb: *const Point) @This() {
    return .{
        .left = lt.x,
        .top = lt.y,
        .right = rb.x,
        .bottom = rb.y,
    };
}

pub fn toD2d(self: *const @This()) d2d1.RECT_F {
    return .{
        .left = self.left,
        .top = self.top,
        .right = self.right,
        .bottom = self.bottom,
    };
}

pub fn movedBy(self: *const @This(), by: *const Point) @This() {
    return .{
        .left = self.left + by.x,
        .top = self.top + by.y,
        .right = self.right + by.x,
        .bottom = self.bottom + by.y,
    };
}

pub fn grownBy(self: *const @This(), by: *const Point) @This() {
    return .{
        .left = self.left - by.x,
        .top = self.top - by.y,
        .right = self.right + by.x,
        .bottom = self.bottom + by.y,
    };
}

pub fn hitBy(self: *const @This(), pt: *const Point) bool {
    return pt.x >= self.left and pt.x < self.right and
        pt.y >= self.top and pt.y < self.bottom;
}

pub fn diag(self: *const @This()) f32 {
    return std.math.hypot(self.width(), self.height());
}

pub fn width(self: *const @This()) f32 {
    return self.right - self.left;
}

pub fn height(self: *const @This()) f32 {
    return self.bottom - self.top;
}
