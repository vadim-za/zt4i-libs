const std = @import("std");
const os = std.os.windows;

const paw = @import("../../paw.zig");
const winmain = @import("../winmain.zig");

// ----------------------------------------------------------------

pub const WndProc = fn (
    hWnd: os.HWND,
    uMsg: os.UINT,
    wParam: os.WPARAM,
    lParam: os.LPARAM,
) callconv(.winapi) os.LRESULT;

extern "user32" fn DefWindowProcW(
    hWnd: os.HWND,
    uMsg: os.UINT,
    wParam: os.WPARAM,
    lParam: os.LPARAM,
) callconv(.winapi) os.LRESULT;

const WndClassW = extern struct {
    style: os.UINT = 0,
    lpfnWndProc: ?*const WndProc = DefWindowProcW,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?os.HINSTANCE,
    hIcon: ?os.HICON = null,
    hCursor: ?os.HCURSOR = null,
    hbrBackground: ?os.HBRUSH = null,
    lpszMenuName: ?os.LPCWSTR = null,
    lpszClassName: ?os.LPCWSTR,
};

const CS_VREDRAW: os.UINT = 1;
const CS_HREDRAW: os.UINT = 2;
const CS_DBLCKLS: os.UINT = 8;

extern "user32" fn RegisterClassW(
    lpWndClass: *const WndClassW,
) callconv(.winapi) os.ATOM;

extern "user32" fn UnregisterClassW(
    lpClassName: ?[*:0]align(1) const os.WCHAR,
    hInstance: ?os.HINSTANCE,
) callconv(.winapi) os.BOOL;

extern "user32" fn LoadIconW(
    hInstance: ?os.HINSTANCE,
    lpIconName: ?[*:0]align(1) const os.WCHAR,
) callconv(.winapi) ?os.HICON;

extern "user32" fn LoadCursorW(
    hInstance: ?os.HINSTANCE,
    lpCursorName: ?[*:0]align(1) const os.WCHAR,
) callconv(.winapi) ?os.HCURSOR;

extern "user32" fn GetWindowLongPtrW(
    hWnd: os.HWND,
    nIndex: c_int,
) callconv(.winapi) os.LONG_PTR;

extern "user32" fn SetWindowLongPtrW(
    hWnd: os.HWND,
    nIndex: c_int,
    dwNewLong: os.LONG_PTR,
) callconv(.winapi) os.LONG_PTR;

const GWLP_WNDPROC: c_int = -4;
const GWLP_USERDATA: c_int = -21;

// ----------------------------------------------------------------

var classAtom: os.ATOM = 0;

pub fn getClass() [*:0]align(1) const os.WCHAR {
    return @ptrFromInt(classAtom);
}

pub fn registerClass() paw.Error!void {
    if (classAtom != 0)
        return;

    const wndClass = WndClassW{
        .style = CS_DBLCKLS, // | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = defaultWindowProc,
        .hInstance = winmain.thisInstance(),
        .hIcon = LoadIconW(
            null,
            @ptrFromInt(32512), // IDI_APPLICATION
        ),
        .hCursor = LoadCursorW(
            null,
            @ptrFromInt(32512), // IDC_ARROW
        ),
        .lpszClassName = std.unicode.utf8ToUtf16LeStringLiteral(
            "PAW Window Class",
        ),
    };

    classAtom = RegisterClassW(&wndClass);
    if (classAtom == 0)
        return paw.Error.OsApi;
}

pub fn unregisterClass() paw.Error!void {
    if (classAtom == 0)
        return;

    if (UnregisterClassW(
        @ptrFromInt(classAtom),
        winmain.thisInstance(),
    ) == 0)
        return paw.Error.OsApi;

    classAtom = 0;
}

pub fn subclass(
    hWnd: os.HWND,
    wndProcW: ?*const WndProc,
    user_ptr: ?*anyopaque,
) void {
    const resolvedWndProcW = wndProcW orelse defaultWindowProc;
    _ = SetWindowLongPtrW(
        hWnd,
        GWLP_USERDATA,
        @bitCast(@intFromPtr(user_ptr)),
    );
    _ = SetWindowLongPtrW(
        hWnd,
        GWLP_WNDPROC,
        @bitCast(@intFromPtr(resolvedWndProcW)),
    );
}

pub fn getUserPtr(Ptr: type, hWnd: os.HWND) Ptr {
    // Zig issue #23041 requires a redundant @as(usize,...) here
    return @ptrFromInt(@as(
        usize,
        @bitCast(GetWindowLongPtrW(
            hWnd,
            GWLP_USERDATA,
        )),
    ));
}

pub const defaultWindowProc = DefWindowProcW;
