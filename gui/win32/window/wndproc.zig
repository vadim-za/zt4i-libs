const std = @import("std");
const winmain = @import("../winmain.zig");
const ReceivedMessage = @import("message_processing.zig").ReceivedMessage;
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;

const os = std.os.windows;

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
            if (winmain.isPanicMode())
                return panicModeWndProc(hWnd, uMsg, wParam, lParam);

            const impl = class.getUserPtr(?*Impl, hWnd).?;
            const window = resps.getCore(impl);

            if (window.hWnd == hWnd) {
                const msg = ReceivedMessage(Impl, resps){
                    .impl = impl,
                    .core = .{
                        .window = window,
                        .uMsg = uMsg,
                        .wParam = wParam,
                        .lParam = lParam,
                    },
                };

                switch (msg.handle()) {
                    .return_value => |value| return value,
                    .call_default => {}, // fall through
                }
            } else if (std.debug.runtime_safety)
                @panic("Window handle mismatch");

            return class.defaultWindowProc(hWnd, uMsg, wParam, lParam);
        }
    };
}

fn panicModeWndProc(
    hWnd: os.HWND,
    uMsg: os.UINT,
    wParam: os.WPARAM,
    lParam: os.LPARAM,
) callconv(.winapi) os.LRESULT {
    const proc = @import("message_processing.zig");

    // Ignore all messages.
    // Do basic processing of WM_PAINT.
    // Prevent WM_CLOSE from destroying the window.
    switch (uMsg) {
        proc.WM_PAINT => {
            var ps: proc.PAINTSTRUCT = undefined;
            _ = proc.BeginPaint(hWnd, &ps);
            _ = proc.EndPaint(hWnd, &ps);
            return 0;
        },
        proc.WM_CLOSE => return 0, // don't destroy the window
        else => return class.DefWindowProcW(hWnd, uMsg, wParam, lParam),
    }
}
