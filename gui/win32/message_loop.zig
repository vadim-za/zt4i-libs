const std = @import("std");
const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?os.HWND,
    wMsgFilterMin: os.UINT,
    wMsgFilterMax: os.UINT,
) callconv(.winapi) os.BOOL;

extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) os.BOOL;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) os.LRESULT;
extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.winapi) void;

const MSG = extern struct {
    hwnd: ?os.HWND,
    message: os.UINT,
    wParam: os.WPARAM,
    lParam: os.LPARAM,
    time: os.DWORD,
    pt: os.POINT,
};

// ----------------------------------------------------------------

pub fn run() void {
    var msg: MSG = undefined;
    while (GetMessageW(&msg, null, 0, 0) != 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}

pub fn stop() void {
    PostQuitMessage(0);
}
