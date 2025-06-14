const std = @import("std");
const builtin = @import("builtin");

const paw = @import("../../paw.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;
const util = @import("util.zig");

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
            core.ddrs.ensureAllReleased();
            util.releaseRenderTarget(core);
            core.hWnd = null;
            return 0;
        }

        fn onPaint(impl: *Impl, hWnd: os.HWND) ?os.LRESULT {
            const core = resps.getCore(impl);

            var ps: PAINTSTRUCT = undefined;
            _ = BeginPaint(hWnd, &ps);
            defer _ = EndPaint(hWnd, &ps);

            const target = util.provideRenderTarget(core) catch {
                if (builtin.mode == .Debug)
                    @panic("Failed to acquire render target");
                return 0; // having no render target is fatal
            };

            core.ddrs.ensureAllCreated(target) catch {
                if (builtin.mode == .Debug)
                    @panic("Failed to create device-dependent resources");
                // failing to create some ddrs might be okay to proceed
            };

            target.beginDraw();
            defer target.endDraw() catch |err| switch (err) {
                error.RecreateTarget => util.releaseRenderTarget(core),
                else => {},
            };
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
