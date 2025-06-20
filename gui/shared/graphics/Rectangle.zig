const std = @import("std");
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
