const std = @import("std");
const builtin = @import("builtin");

pub fn debugModePanic(message: []const u8) void {
    if (builtin.mode == .Debug)
        @panic(message);
}

pub fn safeModePanic(message: []const u8) void {
    if (std.debug.runtime_safety)
        @panic(message);
}

// Weak assertions do not give optimization hints to compiler
// by avoiding using 'unreachable'.
pub inline fn expect(condition: bool) void {
    if (std.debug.runtime_safety and !condition)
        @panic("Weak assertion failed");
}
