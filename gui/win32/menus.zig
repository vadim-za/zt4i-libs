const context = @import("menus/context.zig");
pub const EditContext = context.EditContext;

const editor = @import("menus/editor.zig");
pub const Editor = editor.Editor;

const popup = @import("menus/popup.zig");
pub const Popup = popup.Popup;

comptime {
    const std = @import("std");
    _ = std.testing.refAllDecls(@import("menus/Menu.zig"));
}
