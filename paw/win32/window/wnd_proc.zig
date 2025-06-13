const std = @import("std");
const os = std.os.windows;

const paw = @import("../../paw.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;

// ----------------------------------------------------------------

const WM_DESTROY: os.UINT = 0x2;
const WM_PAINT: os.UINT = 0xF;
const WM_CLOSE: os.UINT = 0x10;
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
            const core = resps.getCore(impl);
            switch (uMsg) {
                WM_DESTROY => {
                    resps.onDestroy(impl);
                    class.subclass(hWnd, null, null);
                    return 0;
                },
                WM_PAINT => {
                    var ps: PAINTSTRUCT = undefined;
                    _ = BeginPaint(hWnd, &ps);
                    defer _ = EndPaint(hWnd, &ps);
                    return 0;
                },
                WM_CLOSE => {
                    if (resps.onClose(impl))
                        core.destroy() catch {
                            if (std.debug.runtime_safety)
                                @panic("Error destroying window");
                        };
                    return 0;
                },
                else => return null,
            }
        }
    };
}
