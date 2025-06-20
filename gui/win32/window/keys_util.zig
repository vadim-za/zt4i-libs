const std = @import("std");
const gui = @import("../../gui.zig");
const MessageCore =
    @import("message_processing.zig").ReceivedMessageCore;

const os = std.os.windows;

fn modifierVKey(modifier: gui.keys.Modifier) c_int {
    return 0x10 + @as(c_int, @intFromEnum(modifier));
}

extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) os.SHORT;

// Must be called synchronously! (That is while processing the message)
pub fn modifierStateSync(modifier: gui.keys.Modifier) bool {
    const vkey = modifierVKey(modifier);
    return GetKeyState(vkey) < 0;
}

// Must be called synchronously! (That is while processing the message)
pub fn modifiersStateSync() gui.keys.Modifiers {
    return .init(.{
        .shift = modifierStateSync(.shift),
        .control = modifierStateSync(.control),
        .alt = modifierStateSync(.alt),
    });
}

fn guiVKeyFromWParam(wParam: os.WPARAM) ?u8 {
    // TODO: Gui Virtual Key codes
    return switch (wParam) {
        '0'...'9', 'A'...'Z' => @intCast(wParam),
        0x08, 0x09, 0x0D, 0x20 => @intCast(wParam),
        else => null,
    };
}

pub fn eventFromMsg(msg: *const MessageCore) ?struct {
    gui.keys.Event,
    bool, // is_char
} {
    if (!(msg.uMsg >= 0x100 and msg.uMsg <= 0x109))
        return null;

    const WM_KEYDOWN = 0x100;
    const WM_KEYUP = 0x101;
    const WM_CHAR = 0x102;

    const prev_down = msg.lParam & 1 << 30 != 0;

    const actions: struct {
        physical: ?gui.keys.Action,
        logical: gui.keys.Action,
    } = switch (msg.uMsg) {
        WM_KEYDOWN, WM_CHAR => .{
            .physical = if (prev_down) null else .down,
            .logical = .down,
        },
        WM_KEYUP => .{
            .physical = .up,
            .logical = .up,
        },
        else => return null,
    };

    var event: gui.keys.Event = .{
        .physical_action = actions.physical,
        .logical_action = actions.logical,
        .modifiers = modifiersStateSync(),
        .vkey = null,
        .char = null,
    };

    switch (msg.uMsg) {
        WM_KEYDOWN, WM_KEYUP => {
            event.vkey = guiVKeyFromWParam(msg.wParam);
            return .{ event, false };
        },
        else => {
            // event.char is to be filled by the caller
            // since multiple events may be required
            return .{ event, true };
        },
    }
}
