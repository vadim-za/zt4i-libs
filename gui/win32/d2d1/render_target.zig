const std = @import("std");
const com = @import("../com.zig");
const d2d1 = @import("../d2d1.zig");
const dwrite = @import("../dwrite.zig");

const os = std.os.windows;

pub const TAG = u64;

pub const RENDER_TARGET_TYPE = enum(u32) {
    DEFAULT = 0,
    SOFTWARE = 1,
    HARDWARE = 2,
};

pub const RENDER_TARGET_USAGE = enum(u32) {
    NONE = 0,
    FORCE_BITMAP_REMOTING = 1,
    GDI_COMPATIBLE = 2,
};

pub const FEATURE_LEVEL = enum(u32) {
    DEFAULT = 0,
    LEVEL_9 = 0x9100, // D3D_FEATURE_LEVEL_9_1
    LEVEL_10 = 0xa000, // D3D_FEATURE_LEVEL_10_0
};

pub const PRESENT_OPTIONS = enum(u32) {
    NONE = 0,
    RETAIN_CONTENTS = 1,
    IMMEDIATELY = 2,
};

pub const RENDER_TARGET_PROPERTIES = extern struct {
    type: RENDER_TARGET_TYPE = .DEFAULT, // default values from d2d1helper.h
    pixelFormat: d2d1.PIXEL_FORMAT = .{},
    dpiX: os.FLOAT = 0.0,
    dpiY: os.FLOAT = 0.0,
    usage: RENDER_TARGET_USAGE = .NONE,
    minLevel: FEATURE_LEVEL = .DEFAULT,
};

pub const HWND_RENDER_TARGET_PROPERTIES = extern struct {
    hwnd: os.HWND,
    pixelSize: d2d1.SIZE_U = .{ .width = 0, .height = 0 }, // default values from d2d1helper.h
    presentOptions: PRESENT_OPTIONS = .NONE,
};

pub const WINDOW_STATE = packed struct(u32) {
    OCCLUDED: bool,
    _: u31,
};

pub const DRAW_TEXT_OPTIONS = packed struct(u32) {
    NO_SNAP: bool = false,
    CLIP: bool = false,
    ENABLE_COLOR_PRINT: bool = false,
    DISABLE_COLOR_BITMAP_SNAPPING: bool = false,
    _: u28 = 0,

    pub const NONE = @This(){};
};

pub const IRenderTarget = extern struct { // ID2D1RenderTarget
    pub const iid = os.GUID.parse("{2cd90694-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = d2d1.IResource;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        CreateBitmap__: *const fn () callconv(.winapi) void,
        CreateBitmapFromWicBitmap__: *const fn () callconv(.winapi) void,
        CreateSharedBitmap__: *const fn () callconv(.winapi) void,
        CreateBitmapBrush__: *const fn () callconv(.winapi) void,
        CreateSolidColorBrush: *const fn (
            self: *Self,
            color: *const d2d1.COLOR_F,
            brushProperties: ?*const d2d1.BRUSH_PROPERTIES,
            solidColorBrush: *?*d2d1.ISolidColorBrush,
        ) callconv(.winapi) os.HRESULT,
        CreateGradientStopCollection__: *const fn () callconv(.winapi) void,
        CreateLinearGradientBrush__: *const fn () callconv(.winapi) void,
        CreateRadialGradientBrush__: *const fn () callconv(.winapi) void,
        CreateCompatibleRenderTarget__: *const fn () callconv(.winapi) void,
        CreateLayer__: *const fn () callconv(.winapi) void,
        CreateMesh__: *const fn () callconv(.winapi) void,
        DrawLine: *const fn (
            self: *Self,
            point0: d2d1.POINT_2F,
            point1: d2d1.POINT_2F,
            brush: *d2d1.IBrush,
            strokeWidth: os.FLOAT,
            strokeStyle: ?*anyopaque, // don't bother with exact type for now
        ) callconv(.winapi) void,
        DrawRectangle: *const fn (
            self: *Self,
            rect: *const d2d1.RECT_F,
            brush: *d2d1.IBrush,
            strokeWidth: os.FLOAT,
            strokeStyle: ?*anyopaque, // don't bother with exact type for now
        ) callconv(.winapi) void,
        FillRectangle: *const fn (
            self: *Self,
            rect: *const d2d1.RECT_F,
            brush: *d2d1.IBrush,
        ) callconv(.winapi) void,
        DrawRoundedRectangle__: *const fn () callconv(.winapi) void,
        FillRoundedRectangle__: *const fn () callconv(.winapi) void,
        DrawEllipse__: *const fn () callconv(.winapi) void,
        FillEllipse__: *const fn () callconv(.winapi) void,
        DrawGeometry: *const fn (
            self: *Self,
            geometry: *d2d1.IGeometry,
            brush: *d2d1.IBrush,
            strokeWidth: os.FLOAT,
            strokeStyle: ?*anyopaque, // don't bother with exact type for now
        ) callconv(.winapi) void,
        FillGeometry: *const fn (
            self: *Self,
            geometry: *d2d1.IGeometry,
            brush: *d2d1.IBrush,
            opacityBrush: ?*d2d1.IBrush,
        ) callconv(.winapi) void,
        FillMesh__: *const fn () callconv(.winapi) void,
        FillOpacityMask__: *const fn () callconv(.winapi) void,
        DrawBitmap__: *const fn () callconv(.winapi) void,
        DrawText: *const fn (
            self: *Self,
            string: [*]const os.WCHAR,
            stringLength: u32,
            textFormat: *dwrite.ITextFormat,
            layoutRect: *const d2d1.RECT_F,
            defaultFillBrush: *d2d1.IBrush,
            options: DRAW_TEXT_OPTIONS,
            measuringMode: dwrite.MEASURING_MODE,
        ) callconv(.winapi) void,
        DrawTextLayout__: *const fn () callconv(.winapi) void,
        DrawGlyphRun__: *const fn () callconv(.winapi) void,
        SetTransform__: *const fn () callconv(.winapi) void,
        GetTransform__: *const fn () callconv(.winapi) void,
        SetAntialiasMode__: *const fn () callconv(.winapi) void,
        GetAntialiasMode__: *const fn () callconv(.winapi) void,
        SetTextAntialiasMode__: *const fn () callconv(.winapi) void,
        GetTextAntialiasMode__: *const fn () callconv(.winapi) void,
        SetTextRenderingParams__: *const fn () callconv(.winapi) void,
        GetTextRenderingParams__: *const fn () callconv(.winapi) void,
        SetTags__: *const fn () callconv(.winapi) void,
        GetTags__: *const fn () callconv(.winapi) void,
        PushLayer__: *const fn () callconv(.winapi) void,
        PopLayer__: *const fn () callconv(.winapi) void,
        Flush__: *const fn () callconv(.winapi) void,
        SaveDrawingState__: *const fn () callconv(.winapi) void,
        RestoreDrawingState__: *const fn () callconv(.winapi) void,
        PushAxisAlignedClip__: *const fn () callconv(.winapi) void,
        PopAxisAlignedClip__: *const fn () callconv(.winapi) void,
        Clear: *const fn (
            self: *Self,
            clearColor: ?*const d2d1.COLOR_F,
        ) callconv(.winapi) void,
        BeginDraw: *const fn (
            self: *Self,
        ) callconv(.winapi) void,
        EndDraw: *const fn (
            self: *Self,
            tag1: ?*TAG,
            tag2: ?*TAG,
        ) callconv(.winapi) os.HRESULT,
        GetPixelFormat__: *const fn () callconv(.winapi) void,
        SetDpi__: *const fn () callconv(.winapi) void,
        GetDpi__: *const fn () callconv(.winapi) void,
        GetSize__: *const fn () callconv(.winapi) void,
        GetPixelSize__: *const fn () callconv(.winapi) void,
        GetMaximumBitmapSize__: *const fn () callconv(.winapi) void,
        IsSupported__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;

    pub fn beginDraw(self: *@This()) void {
        self.vtbl.BeginDraw(self);
    }

    pub fn endDraw(self: *@This()) (com.Error || error{RecreateTarget})!void {
        const hr = self.vtbl.EndDraw(self, null, null);
        if (com.FAILED(hr)) return switch (hr) {
            @as(
                os.HRESULT,
                @bitCast(@as(u32, 0x8899000C)),
            ) => error.RecreateTarget,
            else => com.Error.OsApi,
        };
    }

    pub fn createSolidColorBrush(
        self: *@This(),
        color: *const d2d1.COLOR_F,
    ) com.Error!*d2d1.ISolidColorBrush {
        var result: ?*d2d1.ISolidColorBrush = null;

        if (com.FAILED(self.vtbl.CreateSolidColorBrush(
            self,
            color,
            null,
            &result,
        )))
            return com.Error.OsApi;

        return result orelse com.Error.OsApi;
    }

    pub fn clear(self: *@This(), color: *const d2d1.COLOR_F) void {
        self.vtbl.Clear(self, color);
    }

    pub fn drawLine(
        self: *@This(),
        point0: *const d2d1.POINT_2F,
        point1: *const d2d1.POINT_2F,
        brush: *d2d1.IBrush,
        stroke_width: f32,
    ) void {
        self.vtbl.DrawLine(self, point0.*, point1.*, brush, stroke_width, null);
    }

    pub fn drawRectangle(
        self: *@This(),
        rect: *const d2d1.RECT_F,
        brush: *d2d1.IBrush,
        stroke_width: f32,
    ) void {
        self.vtbl.DrawRectangle(self, rect, brush, stroke_width, null);
    }

    pub fn fillRectangle(
        self: *@This(),
        rect: *const d2d1.RECT_F,
        brush: *d2d1.IBrush,
    ) void {
        self.vtbl.FillRectangle(self, rect, brush);
    }

    pub fn drawGeometry(
        self: *@This(),
        geometry: *d2d1.IGeometry,
        brush: *d2d1.IBrush,
        stroke_width: f32,
    ) callconv(.winapi) void {
        self.vtbl.DrawGeometry(self, geometry, brush, stroke_width, null);
    }

    pub fn fillGeometry(
        self: *@This(),
        geometry: *d2d1.IGeometry,
        brush: *d2d1.IBrush,
    ) callconv(.winapi) void {
        self.vtbl.FillGeometry(self, geometry, brush, null);
    }

    pub fn drawText(
        self: *@This(),
        text: []const os.WCHAR,
        format: *dwrite.ITextFormat,
        rect: *const d2d1.RECT_F,
        brush: *d2d1.IBrush,
    ) void {
        self.vtbl.DrawText(
            self,
            text.ptr,
            @intCast(text.len),
            format,
            rect,
            brush,
            .NONE,
            .NATURAL,
        );
    }
};

pub const IHwndRenderTarget = extern struct { // ID2D1HwndRenderTarget
    pub const iid = os.GUID.parse("{2cd90698-12e2-11dc-9fed-001143a055f9}");
    pub const @".Base" = d2d1.IRenderTarget;
    const Self = @This();

    vtbl: *const Vtbl,
    pub const Vtbl = extern struct {
        @".base": @".Base".Vtbl,
        CheckWindowState: *const fn (
            self: *Self,
        ) callconv(.winapi) WINDOW_STATE,
        Resize__: *const fn () callconv(.winapi) void,
        GetHwnd__: *const fn () callconv(.winapi) void,
    };

    pub const as = com.cast;

    pub fn checkWindowState(self: *@This()) WINDOW_STATE {
        return self.vtbl.CheckWindowState(self);
    }
};
