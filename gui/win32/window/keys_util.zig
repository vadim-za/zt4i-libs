const std = @import("std");
const lib = @import("../../lib.zig");
const MessageCore =
    @import("message_processing.zig").ReceivedMessageCore;

const os = std.os.windows;

fn modifierVKey(modifier: lib.keys.Modifier) c_int {
    return 0x10 + @as(c_int, @intFromEnum(modifier));
}

extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) os.SHORT;

// Must be called synchronously! (That is while processing the message)
pub fn modifierStateSync(modifier: lib.keys.Modifier) bool {
    const vkey = modifierVKey(modifier);
    return GetKeyState(vkey) < 0;
}

// Must be called synchronously! (That is while processing the message)
pub fn modifiersStateSync() lib.keys.Modifiers {
    return .init(.{
        .shift = modifierStateSync(.shift),
        .control = modifierStateSync(.control),
        .alt = modifierStateSync(.alt),
    });
}

pub fn eventFromMsg(msg: *const MessageCore) ?struct {
    lib.keys.Event,
    bool, // is_char
} {
    if (!(msg.uMsg >= 0x100 and msg.uMsg <= 0x109))
        return null;

    const WM_KEYDOWN = 0x100;
    const WM_KEYUP = 0x101;
    const WM_CHAR = 0x102;

    const prev_down = msg.lParam & 1 << 30 != 0;

    const actions: struct {
        physical: ?lib.keys.Action,
        logical: lib.keys.Action,
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

    var event: lib.keys.Event = .{
        .physical_action = actions.physical,
        .logical_action = actions.logical,
        .modifiers = modifiersStateSync(),
        .vkey = null,
        .char = null,
    };

    switch (msg.uMsg) {
        WM_KEYDOWN, WM_KEYUP => {
            if (msg.wParam < 0x100)
                event.vkey = @intCast(msg.wParam);
            return .{ event, false };
        },
        else => {
            // event.char is to be filled by the caller
            // since multiple events may be required
            return .{ event, true };
        },
    }
}
