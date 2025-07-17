const std = @import("std");
const unicode = @import("../unicode.zig");
const lib = @import("../../lib.zig");
const ContentsPool = @import("ContentsPool.zig");

wtf16str: unicode.Wtf16Str(0),
contents_pool: ContentsPool,

pub fn init(self: *@This()) lib.Error!void {
    self.wtf16str.init();
    self.contents_pool.init(lib.allocator());
}

pub fn deinit(self: *@This()) void {
    self.contents_pool.deinit();
    self.wtf16str.deinit();
}

pub fn convertU8(
    self: *@This(),
    str8: []const u8,
) lib.Error![:0]const u16 {
    try self.wtf16str.setU8(str8);
    return self.wtf16str.slice();
}
