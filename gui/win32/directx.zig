const std = @import("std");
const com = @import("com.zig");
const d2d1 = @import("d2d1.zig");
const dwrite = @import("dwrite.zig");

var d2d1_factory: ?*d2d1.IFactory = null;
var dwrite_factory: ?*dwrite.IFactory = null;

pub fn getD2d1Factory() *d2d1.IFactory {
    return d2d1_factory.?;
}

pub fn getDWriteFactory() *dwrite.IFactory {
    return dwrite_factory.?;
}

pub fn init() com.Error!void {
    std.debug.assert(d2d1_factory == null); // repeated initialization not supported
    std.debug.assert(dwrite_factory == null); // repeated initialization not supported

    errdefer deinit();

    d2d1_factory = try d2d1.createFactory(.SINGLE_THREADED);
    dwrite_factory = try dwrite.createFactory(.SHARED);
}

pub fn deinit() void {
    if (d2d1_factory) |factory| {
        com.release(factory);
        d2d1_factory = null;
    }

    if (dwrite_factory) |factory| {
        com.release(factory);
        dwrite_factory = null;
    }
}
