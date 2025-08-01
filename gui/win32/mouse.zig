// Even though this file has no formal dependencies on
// platform-specific types, there is a potential implementation
// dependency: enum values are adjusted to WinAPI.

const std = @import("std");
const graphics = @import("graphics.zig");
const keys = @import("keys.zig");

pub const Action = struct {
    button: ?Button, // null for "move" action
    repeats: u1, // repeat count (0 = single click, 1 = double click)
    type: Type,

    // Currently down/up enum values 0/1 are matched against Windows API message offsets,
    // so the respective conversions on Win32 platform are trivial.
    pub const Type = enum { down, up, move };
};

pub const Button = enum {
    // Currently enum values are matched against Windows API message offsets,
    // so the respective conversions on Win32 platform are trivial.
    left,
    right,
    middle,
};

pub const Buttons = std.EnumSet(Button);

pub const Pos = struct {
    x: i32,
    y: i32,
};

pub const Event = struct {
    action: Action,
    pos: graphics.Point,
    modifiers: keys.Modifiers,
    buttons: Buttons,

    pub fn relativeTo(self: *const @This(), origin: graphics.Point) @This() {
        var new = self.*;
        new.pos = self.point.relativeTo(origin);
        return new;
    }
};
