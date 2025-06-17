const std = @import("std");
const os = std.os.windows;

const gui = @import("../gui.zig");

str16: [:0]u16,

pub fn initU8(str8: []const u8) gui.Error!@This() {
    const str16 = std.unicode.wtf8ToWtf16LeAllocZ(
        gui.allocator(),
        str8,
    ) catch |err| return switch (err) {
        error.OutOfMemory => gui.Error.OutOfMemory,
        error.InvalidWtf8 => gui.Error.Usage,
    };

    return .{ .str16 = str16 };
}

pub fn deinit(self: @This()) void {
    gui.allocator().free(self.str16);
}

pub fn str(self: @This()) [:0]u16 {
    return self.str16;
}

pub fn ptr(self: @This()) [*:0]u16 {
    return self.str16.ptr;
}

// -----------------------------------------------------------

const test_startup = @import("winmain.zig").test_startup;

test "Wtf16Str" {
    test_startup.init();
    defer test_startup.deinit();

    const s16 = try @This().initU8("abc");
    try std.testing.expect(std.mem.order(
        u16,
        std.unicode.wtf8ToWtf16LeStringLiteral("abc"),
        s16.str(),
    ) == .eq);
    s16.deinit();
}
