const std = @import("std");
const gui = @import("../../gui.zig");
const unicode = @import("../unicode.zig");

const EditContextToken = opaque {};

fn isContextType(T: type) bool {
    return @hasDecl(T, "TypeToken") and
        T.TypeToken == EditContextToken;
}

pub fn EditContext(short_text_len: usize) type {
    return struct {
        wtf16str: unicode.Wtf16Str(short_text_len),

        const TypeToken = EditContextToken;

        pub fn init(self: *@This()) void {
            self.wtf16str.init();
        }

        pub fn deinit(self: *@This()) void {
            self.wtf16str.deinit();
        }
    };
}

fn VirtualsFor(Context: type) type {
    comptime std.debug.assert(isContextType(Context));

    return struct {
        fn convertU8(
            anyctx: *anyopaque,
            str8: []const u8,
        ) gui.Error![*:0]const u16 {
            const ctx: *Context = @ptrCast(@alignCast(anyctx));
            try ctx.wtf16str.setU8(str8);
            return ctx.wtf16str.ptr();
        }
    };
}

pub const Any = struct {
    anyctx: *anyopaque,
    vtbl: *const struct {
        convertU8: *const fn (
            anyctx: *anyopaque,
            str8: []const u8,
        ) gui.Error![*:0]const u16,
    },

    pub fn from(edit_context_ptr: anytype) @This() {
        const Context = @TypeOf(edit_context_ptr.*);
        if (!comptime isContextType(Context))
            @compileError("Expected an edit context type, found " ++
                @typeName(Context));

        const Virtuals = VirtualsFor(Context);

        return .{
            .anyctx = edit_context_ptr,
            .vtbl = comptime &.{
                .convertU8 = Virtuals.convertU8,
            },
        };
    }

    pub fn convertU8(
        self: *const @This(),
        str8: []const u8,
    ) gui.Error![*:0]const u16 {
        return self.vtbl.convertU8(self.anyctx, str8);
    }
};
