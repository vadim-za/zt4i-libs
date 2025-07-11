const std = @import("std");
const Contents = @import("Contents.zig");

const os = std.os.windows;

pub const Item = struct {
    pos: Position,
    visible_pos: Position, // may be not up to date
    text16: ?[:0]const u16,
    uIDItem: usize,
    variant: Variant,

    pub fn isVisible(self: *const @This()) bool {
        return switch (self.variant) {
            inline else => |v| v.flags.visible,
        };
    }

    pub fn fromAny(any_variant_ptr: anytype) *@This() {
        const variant = Variant.fromAny(any_variant_ptr);
        return @alignCast(@fieldParentPtr("variant", variant));
    }
};

pub const Position = usize;

pub const Variant = union(enum) {
    command: Command,
    separator: Separator,
    submenu: Submenu,

    pub fn fromAny(any_variant_ptr: anytype) *@This() {
        const VariantType = @TypeOf(any_variant_ptr.*);

        const variant_name = switch (VariantType) {
            Command => "command",
            Separator => "separator",
            Submenu => "submenu",
            else => @compileError("Unknown item type " ++
                @typeName(VariantType)),
        };

        return @alignCast(@fieldParentPtr(variant_name, any_variant_ptr));
    }
};

pub const Command = struct {
    /// 'cookie' is a public field to be written and read by the user code.
    cookie: usize = undefined,

    flags: Flags, // do not change this field directly!

    pub const Flags = packed struct {
        visible: bool = true,
        enabled: bool = true,
        checked: bool = false,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .visible = self.visible,
                .enabled = self.enabled,
                .checked = self.checked,
            };
        }
    };
};

pub const Separator = struct {
    flags: Flags, // do not change this field directly!

    pub const Flags = packed struct {
        visible: bool = true,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .visible = self.visible,
            };
        }
    };
};

pub const Submenu = struct {
    contents: *Contents = undefined,

    flags: Flags, // do not change this field directly!

    pub const Flags = packed struct {
        visible: bool = true,
        enabled: bool = true,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .visible = self.visible,
                .enabled = self.enabled,
            };
        }
    };
};

pub const AllFlags = packed struct {
    visible: bool = true,
    enabled: bool = true,
    checked: bool = false,
};
