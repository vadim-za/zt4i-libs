const std = @import("std");
const gui = @import("../../gui.zig");
const graphics = @import("../graphics.zig");
const dpi = @import("../dpi.zig");
const keys_util = @import("keys_util.zig");
const MessageCore =
    @import("message_processing.zig").ReceivedMessageCore;

const os = std.os.windows;

pub fn eventFromMsg(msg: *const MessageCore) ?gui.mouse.Event {
    const action = actionFromUMsg(msg.uMsg) orelse return null;

    const physical_pos = posFromLParam(msg.lParam);
    const modifiers = modifiersFromWParamSync(msg.wParam);
    const buttons = buttonsFromWParam(msg.wParam);
    const dpr = msg.window.dpr.?;
    const logical_pos = graphics.Point{
        .x = dpi.logicalFromPhysical(dpr, physical_pos.x),
        .y = dpi.logicalFromPhysical(dpr, physical_pos.y),
    };

    return .{
        .action = action,
        .pos = logical_pos,
        .modifiers = modifiers,
        .buttons = buttons,
    };
}

fn actionFromUMsg(uMsg: os.UINT) ?gui.mouse.Action {
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

fn buttonsFromWParam(wParam: os.WPARAM) gui.mouse.Buttons {
    return .init(.{
        .left = (wParam & 1) != 0,
        .right = (wParam & 2) != 0,
        .middle = (wParam & 0x10) != 0,
    });
}

fn posFromLParam(l_param: os.LPARAM) gui.mouse.Pos {
    return .{
        .x = @as(i16, @truncate(l_param)),
        .y = @as(i16, @truncate(l_param >> 16)),
    };
}

// Must be called synchronously! (That is while processing the message)
fn modifiersFromWParamSync(wParam: os.WPARAM) gui.keys.Modifiers {
    return .init(.{
        .shift = (wParam & 4) != 0,
        .control = (wParam & 8) != 0,
        .alt = keys_util.modifierStateSync(.alt),
    });
}
