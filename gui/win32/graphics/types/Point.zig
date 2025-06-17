const d2d1 = @import("../../d2d1.zig");

x: f32,
y: f32,

pub const zero = @This(){ .x = 0, .y = 0 };

pub fn toD2d(self: *const @This()) d2d1.POINT_2F {
    return .{ .x = self.x, .y = self.y };
}

pub fn negated(self: *const @This()) @This() {
    return .{
        .x = -self.x,
        .y = -self.y,
    };
}

pub fn movedBy(self: *const @This(), by: *const @This()) @This() {
    return .{
        .x = self.x + by.x,
        .y = self.y + by.y,
    };
}

pub fn relativeTo(self: *const @This(), origin: *const @This()) @This() {
    return .{
        .x = self.x - origin.x,
        .y = self.y - origin.y,
    };
}
