const std = @import("std");
const gui = @import("../gui.zig");

const os = std.os.windows;

extern "user32" fn SetTimer(
    hWnd: ?os.HWND,
    nIDEvent: usize,
    uElapse: os.UINT,
    lpTimerFunc: *const fn (
        hWnd: ?os.HWND,
        uMsg: os.UINT,
        nIDEvent: usize,
        dwTime: os.DWORD,
    ) callconv(.winapi) void,
) callconv(.winapi) usize;

extern "user32" fn KillTimer(
    hWnd: ?os.HWND,
    nIDEvent: usize,
) callconv(.winapi) os.BOOL;

// const Payload = struct {
//     .....
//     pub fn onTimer(self: *@This()) void { ..... }
// };
// var timer: Timer(Payload) = .{ .payload = .... };
// try timer.setup(period_in_milliseconds);
// defer timer.release();
pub fn Timer(Payload_: type) type {
    return struct {
        pub const Payload = Payload_;
        payload: Payload, // This is a public field
        timer_id: usize = 0, // This is implementation's private field

        pub fn setup(
            self: *@This(),
            period_in_seconds: f32,
        ) gui.Error!void {
            if (self.timer_id != 0)
                return gui.Error.Usage; // timer already set up

            const period_in_milliseconds: os.INT = @intFromFloat(
                @round(period_in_seconds * 1000),
            );

            const nIDEvent = @intFromPtr(&self.payload);
            const uElapse: os.UINT = @max(period_in_milliseconds, 1);

            const timer_id = SetTimer(
                null,
                nIDEvent,
                uElapse,
                &callback,
            );
            if (timer_id == 0)
                return gui.Error.OsApi;

            self.timer_id = timer_id;
        }

        pub fn release(self: *@This()) void {
            if (self.timer_id != 0)
                return; // not set up

            const result = KillTimer(null, self.timer_id);
            std.debug.assert(result);
        }

        fn callback(
            hWnd: ?os.HWND,
            uMsg: os.UINT,
            nIDEvent: usize,
            dwTime: os.DWORD,
        ) callconv(.winapi) void {
            _ = hWnd;
            _ = uMsg;
            _ = dwTime;
            var payload: *Payload = @ptrFromInt(nIDEvent);
            payload.onTimer();
        }
    };
}
