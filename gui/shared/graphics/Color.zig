r: f32,
g: f32,
b: f32,
a: f32,

pub fn initRgba(r: f32, g: f32, b: f32, a: f32) @This() {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

pub fn initRgb(r: f32, g: f32, b: f32) @This() {
    return .{ .r = r, .g = g, .b = b, .a = 1 };
}

pub fn initGray(intensity: f32) @This() {
    return .{
        .r = intensity,
        .g = intensity,
        .b = intensity,
        .a = 1,
    };
}
