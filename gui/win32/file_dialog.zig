const std = @import("std");
const Window = @import("Window.zig");
const gui = @import("../gui.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

// TODO: Use shell common item dialog instead.

const OPENFILENAMEW = extern struct {
    lStructSize: os.DWORD = @sizeOf(@This()),
    hwndOwner: ?os.HWND = null,
    hInstance: ?os.HINSTANCE = null,
    lpstrFilter: ?os.LPCWSTR = null,
    lpstrCustomFilter: ?os.LPWSTR = null,
    nMaxCustFilter: os.DWORD = 0,
    nFilterIndex: os.DWORD = 0,
    lpstrFile: ?[*]u16, // must be initialized
    nMaxFile: os.DWORD, // must be initialized
    lpstrFileTitle: ?os.LPWSTR = null,
    nMaxFileTitle: os.DWORD = 0,
    lpstrInitialDir: ?os.LPCWSTR = null,
    lpstrTitle: ?os.LPCWSTR = null,
    Flags: os.DWORD, // must be initialized
    nFileOffset: os.WORD = 0,
    nFileExtension: os.WORD = 0,
    lpstrDefExt: ?os.LPCWSTR, // must be initialized
    lCustData: os.LPARAM = 0,
    lpfnHook: ?*anyopaque = null,
    lpTemplateName: ?os.LPCWSTR = null,
    pvReserved: ?*anyopaque = null,
    dwReserved: os.DWORD = 0,
    FlagsEx: os.DWORD = 0,
};

const OFN_FILEMUSTEXIST: os.DWORD = 0x1000;
const OFN_OVERWRITEPROMPT: os.DWORD = 2;

extern "comdlg32" fn GetOpenFileNameW(_: *OPENFILENAMEW) callconv(.winapi) os.BOOL;
extern "comdlg32" fn GetSaveFileNameW(_: *OPENFILENAMEW) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

pub const Purpose = enum { open, save };

/// The caller owns the returned slice and must dispose it
/// using gui.allocator()
pub fn run(
    window: ?*Window,
    purpose: Purpose,
) gui.Error!?[:0]u8 {
    const MAX_PATH = 260;
    var file_name_buf: [MAX_PATH]u16 = undefined;
    file_name_buf[0] = 0; // no default file name

    var ofn: OPENFILENAMEW = .{
        .hwndOwner = if (window) |w| w.hWnd.? else null,
        .lpstrFile = (&file_name_buf).ptr,
        .nMaxFile = @intCast(file_name_buf.len),
        .Flags = switch (purpose) {
            .open => OFN_FILEMUSTEXIST,
            .save => OFN_OVERWRITEPROMPT,
        },
        .lpstrDefExt = null,
    };

    const os_call_result = switch (purpose) {
        .open => GetOpenFileNameW(&ofn),
        .save => GetSaveFileNameW(&ofn),
    };
    if (os_call_result == os.FALSE)
        return null;

    const file_name_span = std.mem.sliceTo(&file_name_buf, 0);
    const alloc = gui.allocator();
    const result = try std.unicode.wtf16LeToWtf8AllocZ(
        alloc,
        file_name_span,
    );
    return result;
}
