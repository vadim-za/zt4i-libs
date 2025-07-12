const std = @import("std");
const os = std.os.windows;

const gui = @import("../gui.zig");
const winmain = @import("winmain.zig");

// Buffer length is in u16 characters, not including terminating 0
pub fn Wtf16Str(comptime buf16_len: usize) type {
    // buf_size is guaranteed to be non-zero, even if buf16_len == 0
    const buf_size = (buf16_len + 1) * @sizeOf(u16);

    return struct {
        str16: ?[:0]const u16,
        sfba: std.heap.StackFallbackAllocator(buf_size),
        alloc: std.mem.Allocator,

        pub fn initU8(self: *@This(), str8: []const u8) gui.Error!void {
            self.init();
            try self.setU8(str8);
        }

        pub fn init(self: *@This()) void {
            self.sfba = std.heap.stackFallback(buf_size, winmain.allocator());
            self.alloc = self.sfba.get();
            self.str16 = null;
        }

        pub fn deinit(self: *@This()) void {
            self.reset();
        }

        pub fn setU8(self: *@This(), str8: []const u8) gui.Error!void {
            self.reset();

            self.str16 = std.unicode.wtf8ToWtf16LeAllocZ(
                self.alloc,
                str8,
            ) catch |err| return switch (err) {
                error.OutOfMemory => gui.Error.OutOfMemory,
                error.InvalidWtf8 => gui.Error.Usage,
            };
        }

        pub fn reset(self: *@This()) void {
            if (self.str16) |str16| {
                self.alloc.free(str16);
                self.str16 = null;
            }
        }

        pub fn slice(self: *const @This()) [:0]const u16 {
            return self.str16.?;
        }

        pub fn ptr(self: *const @This()) [*:0]const u16 {
            return self.str16.?.ptr;
        }
    };
}

test "Wtf16Str" {
    winmain.test_startup.init();
    defer winmain.test_startup.deinit();

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
// -----------------------------------------------------------

// Buffer length is in u16 characters, not including terminating 0
pub fn BoundedWtf16Str(comptime buf_len: usize) type {
    return struct {
        buf: [buf_len + 1]u16,
        len: usize,

        pub fn initU8(self: *@This(), str8: []const u8) gui.Error!void {
            const wtf16, _ = wtf8ToWtf16LeTruncateZ(
                &self.buf,
                str8,
                null,
            ) catch |err| return switch (err) {
                error.InvalidWtf8 => gui.Error.Usage,
            };

            std.debug.assert(wtf16.ptr == &self.buf);
            self.len = wtf16.len;
        }

        pub fn slice(self: *const @This()) [:0]const u16 {
            return self.buf[0..self.len :0];
        }

        pub fn ptr(self: *const @This()) [*:0]const u16 {
            return self.slice().ptr;
        }
    };
}

test "BoundedWtf16Str" {
    {
        var s16: BoundedWtf16Str(10) = undefined;
        try s16.initU8("abc");
        try std.testing.expect(std.mem.order(
            u16,
            std.unicode.wtf8ToWtf16LeStringLiteral("abc"),
            s16.slice(),
        ) == .eq);
    }

    {
        var s16_long: BoundedWtf16Str(4) = undefined;
        try s16_long.initU8("abcde");
        try std.testing.expect(std.mem.order(
            u16,
            std.unicode.wtf8ToWtf16LeStringLiteral("a..."),
            s16_long.slice(),
        ) == .eq);
    }
}

// -----------------------------------------------------------

fn wtf16Encode(codepoint: u21, out: *[2]u16) !u2 {
    // Adapted from std.unicode.utf8ToUtf16LeImpl
    if (codepoint < 0x10000) {
        out[0] = std.mem.nativeToLittle(u16, @intCast(codepoint));
        return 1;
    } else {
        const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
        const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
        out.* = .{
            std.mem.nativeToLittle(u16, high),
            std.mem.nativeToLittle(u16, low),
        };
        return 2;
    }
}

test "wtf16Encode" {
    var out: [2]u16 = undefined;

    try std.testing.expectEqual(1, wtf16Encode('A', &out));
    try std.testing.expectEqual('A', out[0]);

    try std.testing.expectEqual(1, wtf16Encode('\u{8A00}', &out));
    try std.testing.expectEqual(0x8A00, out[0]);

    // Surrogate pair
    try std.testing.expectEqual(2, wtf16Encode('\u{10000}', &out));
    try std.testing.expectEqual(0xD800, out[0]);
    try std.testing.expectEqual(0xDC00, out[1]);
}

// Returned bool indicates whether truncation happened.
// The wtf16le buffer must have at least 1 element
// (which is going to hold the trailing 0 value).
fn wtf8ToWtf16LeTruncateZ(
    wtf16le: []u16,
    wtf8: []const u8,
    comptime ellipsis: ?[]const u8, // null means use default ellipsis
) !struct { [:0]u16, bool } {
    std.debug.assert(wtf16le.len >= 1); // space at least for the sentinel

    const ellipsis16 = std.unicode.utf8ToUtf16LeStringLiteral(
        ellipsis orelse "...",
    );

    var idx: usize = 0;
    var ellipsis_pos: usize = 0;
    var it = (try std.unicode.Wtf8View.init(wtf8)).iterator();

    const truncated = while (it.nextCodepoint()) |codepoint21| {
        if (idx + ellipsis16.len < wtf16le.len) // ellipsis + sentinel fit
            ellipsis_pos = idx;

        var codepoint16: [2]u16 = undefined;
        const len_cp = try wtf16Encode(codepoint21, &codepoint16);
        const next_idx = idx + len_cp;
        if (next_idx >= wtf16le.len) // codepoint + sentinel do not fit
            break true;

        @memcpy(wtf16le[idx..][0..len_cp], codepoint16[0..len_cp]);
        idx = next_idx;
    } else false;

    if (truncated) {
        idx = ellipsis_pos;
        var restbuf = wtf16le[idx..];
        const len = @min(ellipsis16.len, restbuf.len - 1); // leave space for sentinel
        @memcpy(restbuf[0..len], ellipsis16[0..len]);

        idx += len;
    }

    wtf16le[idx] = 0;

    return .{ wtf16le[0..idx :0], truncated };
}

test "wtf8ToWtf16LeTruncateZ" {
    var out: [10]u16 = undefined;

    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..4], "ABC", null);
        try std.testing.expect(!truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("ABC"),
            res,
        );
    }

    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..6], "ABCDEF", null);
        try std.testing.expect(truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("AB..."),
            res,
        );
    }

    // Test non-ASCII
    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..4], "A\u{8A00}C", null);
        try std.testing.expect(!truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("A\u{8A00}C"),
            res,
        );
    }

    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..3], "A\u{8A00}C", null);
        try std.testing.expect(truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral(".."),
            res,
        );
    }

    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..5], "A\u{8A00}CDE", null);
        try std.testing.expect(truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("A..."),
            res,
        );
    }

    // Test surrogate pair
    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..8], "AB\u{10000}DEF", null);
        try std.testing.expect(!truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("AB\u{10000}DEF"),
            res,
        );
    }

    {
        const res, const truncated =
            try wtf8ToWtf16LeTruncateZ(out[0..7], "AB\u{10000}DEF", null);
        try std.testing.expect(truncated);
        try std.testing.expectEqualSentinel(
            u16,
            0,
            std.unicode.wtf8ToWtf16LeStringLiteral("AB..."),
            res,
        );
    }
}
