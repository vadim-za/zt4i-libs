const std = @import("std");
const com = @import("../com.zig");
const dwrite = @import("../dwrite.zig");

const os = std.os.windows;

pub const ITextFormat = extern struct { // IDWriteTextFormat
    pub const iid = os.GUID.parse("{9c906818-31d7-4fd3-a151-7c5e225db55a}");
    pub const @".Base" = com.IUnknown;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        SetTextAlignment__: *const fn () callconv(.winapi) void,
        SetParagraphAlignment__: *const fn () callconv(.winapi) void,
        SetWordWrapping__: *const fn () callconv(.winapi) void,
        SetReadingDirection__: *const fn () callconv(.winapi) void,
        SetFlowDirection__: *const fn () callconv(.winapi) void,
        SetIncrementalTabStop__: *const fn () callconv(.winapi) void,
        SetTrimming__: *const fn () callconv(.winapi) void,
        SetLineSpacing__: *const fn () callconv(.winapi) void,
        GetTextAlignment__: *const fn () callconv(.winapi) void,
        GetParagraphAlignment__: *const fn () callconv(.winapi) void,
        GetWordWrapping__: *const fn () callconv(.winapi) void,
        GetReadingDirection__: *const fn () callconv(.winapi) void,
        GetFlowDirection__: *const fn () callconv(.winapi) void,
        GetIncrementalTabStop__: *const fn () callconv(.winapi) void,
        GetTrimming__: *const fn () callconv(.winapi) void,
        GetLineSpacing__: *const fn () callconv(.winapi) void,
        GetFontCollection__: *const fn () callconv(.winapi) void,
        GetFontFamilyNameLength__: *const fn () callconv(.winapi) void,
        GetFontFamilyName__: *const fn () callconv(.winapi) void,
        GetFontWeight__: *const fn () callconv(.winapi) void,
        GetFontStyle__: *const fn () callconv(.winapi) void,
        GetFontStretch__: *const fn () callconv(.winapi) void,
        GetFontSize__: *const fn () callconv(.winapi) void,
        GetLocaleName__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;
};
