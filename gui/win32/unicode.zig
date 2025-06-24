const std = @import("std");
const os = std.os.windows;

const gui = @import("../gui.zig");
const winmain = @import("winmain.zig");

pub fn Wtf16Str(comptime buf_size: usize) type {
    return struct {
        str16: [:0]const u16,
        sfba: std.heap.StackFallbackAllocator(buf_size),
        alloc: std.mem.Allocator,

        pub fn initU8(self: *@This(), str8: []const u8) gui.Error!void {
            self.sfba = std.heap.stackFallback(buf_size, winmain.allocator());
            self.alloc = self.sfba.get();

            self.str16 = std.unicode.wtf8ToWtf16LeAllocZ(
                self.alloc,
                str8,
            ) catch |err| return switch (err) {
                error.OutOfMemory => gui.Error.OutOfMemory,
                error.InvalidWtf8 => gui.Error.Usage,
            };
        }

        pub fn deinit(self: *const @This()) void {
            self.alloc.free(self.str16);
        }

        pub fn slice(self: *const @This()) [:0]const u16 {
            return self.str16;
        }

        pub fn ptr(self: *const @This()) [*:0]const u16 {
            return self.str16.ptr;
        }
    };
}
// -----------------------------------------------------------

const test_startup = @import("winmain.zig").test_startup;

test "Wtf16Str" {
    test_startup.init();
    defer test_startup.deinit();

    {
        var s16: Wtf16Str(10) = undefined;
        try s16.initU8("abc");
        defer s16.deinit();
        try std.testing.expect(std.mem.order(
            u16,
            std.unicode.wtf8ToWtf16LeStringLiteral("abc"),
            s16.slice(),
        ) == .eq);
    }

    {
        var s16_long: Wtf16Str(3) = undefined;
        try s16_long.initU8("abcde");
        defer s16_long.deinit();
        try std.testing.expect(std.mem.order(
            u16,
            std.unicode.wtf8ToWtf16LeStringLiteral("abcde"),
            s16_long.slice(),
        ) == .eq);
    }
}
