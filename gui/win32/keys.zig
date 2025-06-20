const std = @import("std");

pub const Action = enum {
    // Currently down/up enum values 0/1 are matched against Windows API message offsets,
    // so the respective conversions on Win32 platform are trivial.
    down,
    up,
};

pub const Event = struct {
    physical_action: ?Action, // null if autorepeat
    logical_action: Action, // .down on autorepeat
    modifiers: Modifiers,

    // Some or all of the .vk and .char may be null
    vkey: ?u8, // can be sent with .down and .up actions
    char: ?u21, // unicode codepoint, can only be sent with .down actions
};

// The order of modifiers matches the order of VK_... codes,
// so that the modifier VK_ code is 0x10 + @intFromEnum(modifier)
pub const Modifier = enum { shift, control, alt };
pub const Modifiers = std.EnumSet(Modifier);
