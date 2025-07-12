const std = @import("std");
const unicode = @import("../unicode.zig");
const gui = @import("../../gui.zig");

wtf16str: unicode.Wtf16Str(0),

pub fn init(self: *@This()) gui.Error!void {
    self.wtf16str.init();
}

pub fn deinit(self: *@This()) void {
    self.wtf16str.deinit();
}

pub fn convertU8(
    self: *@This(),
    str8: []const u8,
) gui.Error![:0]const u16 {
    try self.wtf16str.setU8(str8);
    return self.wtf16str.slice();
}
