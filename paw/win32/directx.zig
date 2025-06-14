const std = @import("std");
const com = @import("com.zig");
const d2d1 = @import("d2d1.zig");

var d2d1_factory: ?*d2d1.IFactory = null;

pub fn getD2d1Factory() *d2d1.IFactory {
    return d2d1_factory.?;
}

pub fn init() com.Error!void {
    std.debug.assert(d2d1_factory == null); // repeated initialization not supported
    errdefer deinit();
    d2d1_factory = try d2d1.createFactory(d2d1.IFactory, .SINGLE_THREADED);
}

pub fn deinit() void {
    if (d2d1_factory) |factory| {
        com.release(factory);
        d2d1_factory = null;
    }
}
