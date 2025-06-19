const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../../gui.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;
const d2d1 = @import("../d2d1.zig");
const graphics = @import("../graphics.zig");
const mouse = @import("../mouse.zig");
const mouse_util = @import("mouse_util.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

const WM_DESTROY: os.UINT = 0x2;
const WM_PAINT: os.UINT = 0xF;
const WM_CLOSE: os.UINT = 0x10;
const WM_DISPLAYCHANGE: os.UINT = 0x7E;
const WM_KEYDOWN: os.UINT = 0x100;

extern "user32" fn BeginPaint(hWnd: os.HWND, lpPaint: *PAINTSTRUCT) callconv(.winapi) ?os.HDC;
extern "user32" fn EndPaint(hWnd: os.HWND, lpPaint: *const PAINTSTRUCT) callconv(.winapi) os.BOOL;

const PAINTSTRUCT = extern struct {
    hdc: os.HDC,
    fErase: os.BOOL,
    rcPaint: os.RECT,
    fRestore: os.BOOL,
    fIncUpdate: os.BOOL,
    rgbReserved: [32]os.BYTE,
};

// ----------------------------------------------------------------

pub fn ReceivedMessage(
    Impl: type,
    comptime resps: Responders(Impl),
) type {
    return struct {
        impl: *Impl,
        core: *Window,
        uMsg: os.UINT,
        wParam: os.WPARAM,
        lParam: os.LPARAM,

        pub const Result = union(enum) {
            return_value: os.LRESULT,
            call_default: void,

            const zero = @This(){ .return_value = 0 };
        };

        pub fn handle(
            self: *const @This(),
        ) Result {
            // if(handleAsMouseMessage()) |result|
            //     return result;
            return switch (self.uMsg) {
                WM_DESTROY => self.onDestroy(),
                WM_PAINT, WM_DISPLAYCHANGE => self.onPaint(),
                WM_CLOSE => self.onClose(),
                else => .call_default,
            };
        }

        fn onDestroy(self: *const @This()) Result {
            resps.onDestroy(self.impl);
            class.subclass(self.core.hWnd.?, null, null);
            self.core.device_resources.releaseResources();
            self.core.hWnd = null;
            return .zero;
        }

        fn onPaint(self: *const @This()) Result {
            var ps: PAINTSTRUCT = undefined;
            _ = BeginPaint(self.core.hWnd.?, &ps);
            defer _ = EndPaint(self.core.hWnd.?, &ps);

            const hwnd_target =
                self.core.device_resources.provideResourcesFor(
                    self.core.hWnd.?,
                ) catch {
                    // having no render target or resources is fatal
                    if (builtin.mode == .Debug)
                        @panic("Failed to create window device resources");
                    return .zero;
                };

            if (hwnd_target.checkWindowState().OCCLUDED)
                return .zero;

            const target = hwnd_target.as(d2d1.IRenderTarget);
            target.beginDraw();
            defer target.endDraw() catch |err| switch (err) {
                error.RecreateTarget => self.core
                    .device_resources.releaseResources(),
                else => {},
            };

            var dc = graphics.DrawContext{
                .target = target,
                .origin = .zero,
            };
            resps.onPaint(self.impl, &dc);
            return .zero;
        }

        fn onClose(self: *const @This()) Result {
            if (resps.onClose(self.impl))
                self.core.destroy();
            return .zero;
        }
    };
}
