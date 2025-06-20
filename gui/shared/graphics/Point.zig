x: f32,
y: f32,

pub const zero = @This(){ .x = 0, .y = 0 };

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
