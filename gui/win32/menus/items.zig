const std = @import("std");
const Contents = @import("Contents.zig");

const os = std.os.windows;

pub const Item = struct {
    index: usize, // 0-based, includes anchors
    visible_pos: usize, // does not include anchors, may be not up to date
    variant: Variant,

    pub fn isVisible(self: *const @This()) bool {
        return self.variant != .anchor;
    }

    pub fn fromAny(any_variant_ptr: anytype) *@This() {
        const variant = Variant.fromAny(any_variant_ptr);
        return @alignCast(@fieldParentPtr("variant", variant));
    }

    pub fn deinit(self: *@This()) void {
        switch (self.variant) {
            inline else => |*v| v.deinit(),
        }
    }
};

pub const Variant = union(enum) {
    command: Command,
    separator: Separator,
    submenu: Submenu,
    anchor: Anchor,

    pub fn fromAny(any_variant_ptr: anytype) *@This() {
        const VariantType = @TypeOf(any_variant_ptr.*);

        const variant_name = switch (VariantType) {
            Command => "command",
            Separator => "separator",
            Submenu => "submenu",
            Anchor => "anchor",
            else => @compileError("Unknown item type " ++
                @typeName(VariantType)),
        };

        return @alignCast(@fieldParentPtr(variant_name, any_variant_ptr));
    }
};

pub const Command = struct {
    /// You can read this field but do not change it directly!
    flags: Flags,

    pub const Flags = packed struct {
        enabled: bool = true,
        checked: bool = false,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .enabled = self.enabled,
                .checked = self.checked,
            };
        }
    };

    pub fn deinit(_: *@This()) void {}
};

pub const Separator = struct {
    /// You can read this field but do not change it directly!
    flags: Flags,

    pub const Flags = packed struct {
        pub fn toAll(self: @This()) AllFlags {
            _ = self;
            return .{};
        }
    };

    pub fn deinit(_: *@This()) void {}
};

pub const Submenu = struct {
    contents: *Contents = undefined,

    /// You can read this field but do not change it directly!
    flags: Flags,

    pub const Flags = packed struct {
        enabled: bool = true,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .enabled = self.enabled,
            };
        }
    };

    pub fn deinit(self: *@This()) void {
        self.contents.deinit();
    }
};

pub const Anchor = struct {
    /// You can read this field but do not change it directly!
    flags: Flags,

    pub const Flags = packed struct {
        pub fn toAll(self: @This()) AllFlags {
            _ = self;
            return .{};
        }
    };

    pub fn deinit(_: *@This()) void {}
};

pub const AllFlags = packed struct {
    enabled: bool = true,
    checked: bool = false,
};
