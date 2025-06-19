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

        pub fn handle(
            self: *const @This(),
        ) ?os.LRESULT {
            return switch (self.uMsg) {
                WM_DESTROY => self.onDestroy(),
                WM_PAINT, WM_DISPLAYCHANGE => self.onPaint(),
                WM_CLOSE => self.onClose(),
                else => null,
            };
        }

        fn onDestroy(self: *const @This()) ?os.LRESULT {
            resps.onDestroy(self.impl);
            class.subclass(self.core.hWnd.?, null, null);
            self.core.device_resources.releaseResources();
            self.core.hWnd = null;
            return 0;
        }

        fn onPaint(self: *const @This()) ?os.LRESULT {
            var ps: PAINTSTRUCT = undefined;
            _ = BeginPaint(self.core.hWnd.?, &ps);
            defer _ = EndPaint(self.core.hWnd.?, &ps);

            const hwnd_target =
                self.core.device_resources.provideResourcesFor(
                    self.core.hWnd.?,
                ) catch {
                    if (builtin.mode == .Debug)
                        @panic("Failed to create window device resources");
                    return 0; // having no render target or resources is fatal
                };

            if (hwnd_target.checkWindowState().OCCLUDED)
                return 0;

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
            return 0;
        }

        fn onClose(self: *const @This()) ?os.LRESULT {
            if (resps.onClose(self.impl))
                self.core.destroy();
            return 0;
        }
    };
}
