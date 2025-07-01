const std = @import("std");
const builtin = @import("builtin");
const winmain = @import("winmain.zig");
const gui = @import("../gui.zig");

const os = std.os.windows;

extern "user32" fn SetTimer(
    hWnd: ?os.HWND,
    nIDEvent: usize,
    uElapse: os.UINT,
    lpTimerFunc: *const TIMERPROC,
) callconv(.winapi) usize;

extern "user32" fn KillTimer(
    hWnd: ?os.HWND,
    nIDEvent: usize,
) callconv(.winapi) os.BOOL;

const TIMERPROC = fn (
    hWnd: ?os.HWND,
    uMsg: os.UINT,
    nIDEvent: usize,
    dwTime: os.DWORD,
) callconv(.winapi) void;

const TimerCore = struct {
    nIDEvent: usize = 0,

    fn setupWithinWindow(
        self: *@This(),
        window: *gui.Window,
        timeout: f32,
        impl: *anyopaque,
        callback: *const TIMERPROC,
    ) gui.Error!void {
        if (self.active())
            return gui.Error.Usage; // timer already set up

        const nIDEvent: usize = @intFromPtr(impl);

        const timeout_ms: os.INT = @intFromFloat(@round(timeout * 1000));
        const uElapse: os.UINT = @max(timeout_ms, 1);

        const result = SetTimer(
            window.hWnd.?,
            nIDEvent,
            uElapse,
            callback,
        );
        if (result == 0)
            return gui.Error.OsApi;

        self.nIDEvent = nIDEvent;
    }

    fn releaseWithinWindow(self: *@This(), window: *gui.Window) void {
        if (!self.active()) {
            std.debug.assert(false);
            return;
        }

        const result = KillTimer(window.hWnd.?, self.nIDEvent);
        std.debug.assert(result != os.FALSE);
    }

    fn active(self: *const @This()) bool {
        return self.nIDEvent != 0;
    }
};

pub fn Timer(Payload: type) type {
    return struct {
        core: TimerCore = .{},
        payload: Payload, // public field

        pub fn setupWithinWindow(
            self: *@This(),
            window: *gui.Window,
            timeout: f32,
        ) gui.Error!void {
            return self.core.setupWithinWindow(
                window,
                timeout,
                self,
                callbackForWindow,
            );
        }

        pub fn releaseWithinWindow(self: *@This(), window: *gui.Window) void {
            self.core.releaseWithinWindow(window);
        }

        pub fn active(self: *const @This()) bool {
            return self.core.active();
        }

        fn callbackForWindow(
            hWnd: ?os.HWND,
            uMsg: os.UINT,
            nIDEvent: usize,
            dwTime: os.DWORD,
        ) callconv(.winapi) void {
            _ = hWnd;
            _ = uMsg;
            _ = dwTime;
            if (winmain.isPanicMode())
                return;

            const self: *@This() = @ptrFromInt(nIDEvent);
            self.payload.onTimer();
        }
    };
}
