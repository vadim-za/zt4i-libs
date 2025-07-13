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

    /// Can be sent with .down and .up actions, but shouldn't
    /// be assumed to have a non-null value for those messages.
    /// Contains a system
    vkey: ?u8,
    char: ?u21, // unicode codepoint, can only be sent with .down actions
};

// The order of modifiers matches the order of VK_... codes,
// so that the modifier VK_ code is 0x10 + @intFromEnum(modifier)
pub const Modifier = enum { shift, control, alt };
pub const Modifiers = std.EnumSet(Modifier);

/// Virtual Keys.
/// The specific virtual key codes are potentially subject to change
/// both across different platforms and even across different versions
/// of the library on the same platform. Do not permanently serialize.
///
/// The values which are supposed to stay unchanged are:
///   - The Latin characters 'A'...'Z'
///   - The decimal digits '0'...'9'
///   - Backspace 0x08, Tab 0x09, Return 0x0D, Escape 0x1B, Space 0x20
/// On Windows, other values are directly forwarded from the OS API
/// (consider them platform-specific for the time being).
///
/// This namespace contains platform-independent defines for some of them,
/// in the sense that as long as you refer to these defines and not to their
/// specific values, your code should be platform-independent.
pub const Vk = struct {
    // Use WINAPI values directly
    pub const left: u8 = 0x25;
    pub const up: u8 = 0x26;
    pub const right: u8 = 0x27;
    pub const down: u8 = 0x28;

    pub inline fn F(n: u8) u8 {
        std.debug.assert(n >= 1 and n <= 12);
        return 0x70 + (n - 1);
    }
};
