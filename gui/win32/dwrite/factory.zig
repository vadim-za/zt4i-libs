const std = @import("std");
const com = @import("../com.zig");
const dwrite = @import("../dwrite.zig");
const Wtf16Str = @import("../Wtf16Str.zig");

const os = std.os.windows;

pub const IFactory = extern struct { // IDWriteFactory
    pub const iid = os.GUID.parse("{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}");
    pub const @".Base" = com.IUnknown;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        GetSystemFontCollection__: *const fn () callconv(.winapi) void,
        CreateCustomFontCollection__: *const fn () callconv(.winapi) void,
        RegisterFontCollectionLoader__: *const fn () callconv(.winapi) void,
        UnregisterFontCollectionLoader__: *const fn () callconv(.winapi) void,
        CreateFontFileReference__: *const fn () callconv(.winapi) void,
        CreateCustomFontFileReference__: *const fn () callconv(.winapi) void,
        CreateFontFace__: *const fn () callconv(.winapi) void,
        CreateRenderingParams__: *const fn () callconv(.winapi) void,
        CreateMonitorRenderingParams__: *const fn () callconv(.winapi) void,
        CreateCustomRenderingParams__: *const fn () callconv(.winapi) void,
        RegisterFontFileLoader__: *const fn () callconv(.winapi) void,
        UnregisterFontFileLoader__: *const fn () callconv(.winapi) void,
        CreateTextFormat: *const fn (
            self: *Self,
            fontFamilyName: [*:0]const os.WCHAR,
            fontCollection: ?*const anyopaque, // IDWriteFontCollection
            fontWeight: dwrite.FONT_WEIGHT,
            fontStyle: dwrite.FONT_STYLE,
            fontStretch: dwrite.FONT_STRETCH,
            fontSize: os.FLOAT,
            localeName: [*:0]const os.WCHAR,
            *?*dwrite.ITextFormat,
        ) callconv(.winapi) os.HRESULT,
        CreateTypography__: *const fn () callconv(.winapi) void,
        GetGdiInterop__: *const fn () callconv(.winapi) void,
        CreateTextLayout__: *const fn () callconv(.winapi) void,
        CreateGdiCompatibleTextLayout__: *const fn () callconv(.winapi) void,
        CreateEllipsisTrimmingSign__: *const fn () callconv(.winapi) void,
        CreateTextAnalyzer__: *const fn () callconv(.winapi) void,
        CreateNumberSubstitution__: *const fn () callconv(.winapi) void,
        CreateGlyphRunAnalysis__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;

    pub fn createTextFormat(
        self: *@This(),
        font_family: []const u8,
        font_collection: ?*const anyopaque, // IDWriteFontCollection
        font_weight: dwrite.FONT_WEIGHT,
        font_style: dwrite.FONT_STYLE,
        font_stretch: dwrite.FONT_STRETCH,
        font_size: f32,
    ) com.Error!*dwrite.ITextFormat {
        var result: ?*dwrite.ITextFormat = null;

        {
            const font_family16: Wtf16Str = try .initU8(font_family);
            defer font_family16.deinit();
            if (com.FAILED(self.vtbl.CreateTextFormat(
                self,
                font_family16.ptr(),
                font_collection,
                font_weight,
                font_style,
                font_stretch,
                font_size,
                std.unicode.utf8ToUtf16LeStringLiteral(""),
                &result,
            )))
                return com.Error.OsApi;
        }

        return result orelse com.Error.OsApi;
    }
};

pub const FACTORY_TYPE = enum(c_uint) { // DWRITE_FACTORY_TYPE
    SHARED = 0,
    ISOLATED = 1,
};

extern "dwrite" fn DWriteCreateFactory(
    factoryType: FACTORY_TYPE,
    riid: com.REFIID,
    factory: *?*anyopaque,
) callconv(.winapi) os.HRESULT;

pub fn createFactory(
    factory_type: FACTORY_TYPE,
) com.Error!*IFactory {
    var result: ?*IFactory = null;

    if (com.FAILED(DWriteCreateFactory(
        factory_type,
        &IFactory.iid,
        @ptrCast(&result),
    )))
        return com.Error.OsApi;

    return result orelse com.Error.OsApi;
}
