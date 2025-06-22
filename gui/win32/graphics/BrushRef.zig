// Objects of this type can be used only temporarily,
// as long as the actual brush objects exist.
//
// These objects can be freely copied.
// No reference counting is done.

const d2d1 = @import("../d2d1.zig");

ibrush: *d2d1.IBrush,

pub fn init(brush: *d2d1.IBrush) @This() {
    return .{ .ibrush = brush };
}
