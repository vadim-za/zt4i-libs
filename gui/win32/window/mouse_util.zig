const std = @import("std");
const gui = @import("../../gui.zig");

const os = std.os.windows;

pub fn actionFromMsg(uMsg: os.UINT) ?gui.mouse.Action {
    if (!(uMsg >= 0x200 and uMsg <= 0x20E))
        return null;

    return switch (uMsg) {
        0x200 => .{ .button = null, .type = .move, .repeats = 0 },
        0x201...0x209 => msg: {
            const button_idx = (uMsg - 0x201) / 3;
            const type_idx = (uMsg - 0x201) % 3;
            break :msg .{
                .button = @enumFromInt(button_idx),
                .type = @enumFromInt(type_idx % 2), // dblclk -> down
                .repeats = if (type_idx == 2) 1 else 0,
            };
        },
        else => null,
    };
}

pub fn buttonsFromWParam(wParam: os.WPARAM) gui.mouse.Buttons {
    return .init(.{
        .left = (wParam & 1) != 0,
        .right = (wParam & 2) != 0,
        .middle = (wParam & 0x10) != 0,
    });
}

pub fn posFromLParam(l_param: os.LPARAM) gui.mouse.Pos {
    return .{
        .x = @as(i16, @truncate(l_param)),
        .y = @as(i16, @truncate(l_param >> 16)),
    };
}

const VK_MENU = 0x12;
extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) os.SHORT;

// Must be called synchronously! (That is while processing the message)
pub fn modifiersFromWParamSync(wParam: os.WPARAM) gui.mouse.Modifiers {
    return .init(.{
        .shift = (wParam & 4) != 0,
        .control = (wParam & 8) != 0,
        .alt = GetKeyState(VK_MENU) < 0,
    });
}
