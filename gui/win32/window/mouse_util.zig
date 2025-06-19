const std = @import("std");
const mouse = @import("../mouse.zig");

const os = std.os.windows;

pub fn actionFromMsg(msg: os.UINT) ?mouse.Action {
    if (!(msg >= 0x200 and msg <= 0x20E)) return null;
    switch (msg) {
        0x200 => return .{ .button = null, .type = .move, .repeats = 0 },
        0x201...0x209 => return .{
            .button = @enumFromInt((msg - 0x201) / 3),
            .type = @enumFromInt((msg - 0x201) % 2), // dblclk -> down
            .repeats = if ((msg - 0x201) % 3 == 2) 1 else 0,
        },
        else => return null,
    }
}

pub fn buttonsFromWParam(wParam: os.WPARAM) mouse.Buttons {
    return .init(.{
        .left = (wParam & 1) != 0,
        .right = (wParam & 2) != 0,
        .middle = (wParam & 0x10) != 0,
    });
}

pub fn posFromLParam(l_param: os.LPARAM) mouse.Pos {
    return .{
        .x = @as(i16, @truncate(l_param)),
        .y = @as(i16, @truncate(l_param >> 16)),
    };
}

const VK_MENU = 0x12;
extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) os.SHORT;

// Must be called synchronously! (That is while processing the message)
pub fn modifiersFromWParamSync(wParam: os.WPARAM) mouse.Modifiers {
    return .init(.{
        .shift = (wParam & 4) != 0,
        .control = (wParam & 8) != 0,
        .alt = GetKeyState(VK_MENU) < 0,
    });
}
