const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../../gui.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;
const d2d1 = @import("../d2d1.zig");
const graphics = @import("../graphics.zig");

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

pub fn make(
    Impl: type,
    comptime resps: Responders(Impl),
) *const class.WndProc {
    return Container(Impl, resps).wndProc;
}

fn Container(
    Impl: type,
    comptime resps: Responders(Impl),
) type {
    return struct {
        fn wndProc(
            hWnd: os.HWND,
            uMsg: os.UINT,
            wParam: os.WPARAM,
            lParam: os.LPARAM,
        ) callconv(.winapi) os.LRESULT {
            const impl = class.getUserPtr(?*Impl, hWnd).?;

            if (std.debug.runtime_safety)
                std.debug.assert(resps.getCore(impl).hWnd == hWnd);

            return handleMsg(impl, hWnd, uMsg, wParam, lParam) orelse
                class.defaultWindowProc(hWnd, uMsg, wParam, lParam);
        }

        fn handleMsg(
            impl: *Impl,
            hWnd: os.HWND,
            uMsg: os.UINT,
            _: os.WPARAM,
            _: os.LPARAM,
        ) ?os.LRESULT {
            return switch (uMsg) {
                WM_DESTROY => onDestroy(impl, hWnd),
                WM_PAINT, WM_DISPLAYCHANGE => onPaint(impl, hWnd),
                WM_CLOSE => onClose(impl),
                else => null,
            };
        }

        fn onDestroy(impl: *Impl, hWnd: os.HWND) ?os.LRESULT {
            const core = resps.getCore(impl);

            resps.onDestroy(impl);
            class.subclass(hWnd, null, null);
            core.device_resources.releaseResources();
            core.hWnd = null;
            return 0;
        }

        fn onPaint(impl: *Impl, hWnd: os.HWND) ?os.LRESULT {
            const core = resps.getCore(impl);

            var ps: PAINTSTRUCT = undefined;
            _ = BeginPaint(hWnd, &ps);
            defer _ = EndPaint(hWnd, &ps);

            const hwnd_target =
                core.device_resources.provideResourcesFor(hWnd) catch {
                    if (builtin.mode == .Debug)
                        @panic("Failed to create window device resources");
                    return 0; // having no render target or resources is fatal
                };

            if (hwnd_target.checkWindowState().OCCLUDED)
                return 0;

            const target = hwnd_target.as(d2d1.IRenderTarget);
            target.beginDraw();
            defer target.endDraw() catch |err| switch (err) {
                error.RecreateTarget => core
                    .device_resources.releaseResources(),
                else => {},
            };

            var dc = graphics.DrawContext{
                .target = target,
                .origin = .zero,
            };
            resps.onPaint(impl, &dc);
            return 0;
        }

        fn onClose(impl: *Impl) ?os.LRESULT {
            const core = resps.getCore(impl);

            if (resps.onClose(impl))
                core.destroy();
            return 0;
        }
    };
}
