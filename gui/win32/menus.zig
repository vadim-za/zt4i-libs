pub const Contents = @import("menus/Contents.zig");
pub const Popup = @import("menus/Popup.zig");
pub const Bar = @import("menus/Bar.zig");

const items = @import("menus/items.zig");
pub const Command = items.Command;
pub const Separator = items.Separator;
pub const Submenu = items.Submenu;
pub const Anchor = items.Anchor;
pub const Where = items.Where;

comptime {
    const std = @import("std");
    _ = std.testing.refAllDecls(@This());
}
