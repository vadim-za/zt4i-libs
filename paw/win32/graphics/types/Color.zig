const d2d1 = @import("../../d2d1.zig");

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn initRgba(r: f32, g, f32, b: f32, a: f32) @This() {
        return .{ .r = r, .g = .g, .b = b, .a = a };
    }

    pub fn initRgb(r: f32, g, f32, b: f32, a: f32) @This() {
        return .{ .r = r, .g = .g, .b = b, .a = 1 };
    }

    pub fn toD2d(self: @This()) d2d1.COLOR_F {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }
};
