const std = @import("std");
const Contents = @import("Contents.zig");
const lib_imports = @import("../../lib_imports.zig");
const cc = lib_imports.cc;

const os = std.os.windows;

pub const ItemsList = cc.List(Item, .{
    .implementation = .{ .double_linked = .null_terminated },
    .hook_field = "list_hook",
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});

pub const Item = struct {
    // 'index' and 'visible_pos' may be not up to date
    index: usize, // 0-based, increments over all items
    visible_pos: usize, // 0-based, does not increment over anchors
    variant: Variant,

    list_hook: ItemsList.Hook,

    owner: if (std.debug.runtime_safety) *Contents else void,

    pub fn isVisible(self: *const @This()) bool {
        return self.variant != .anchor;
    }

    pub fn nextVisiblePos(self: *const @This()) usize {
        return if (self.isVisible())
            self.visible_pos + 1
        else
            self.visible_pos;
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
        return @alignCast(@fieldParentPtr(
            variantName(@TypeOf(any_variant_ptr.*)),
            any_variant_ptr,
        ));
    }

    fn variantName(VariantType: type) [:0]const u8 {
        return switch (VariantType) {
            Command => "command",
            Separator => "separator",
            Submenu => "submenu",
            Anchor => "anchor",
            else => @compileError("Unknown item type " ++
                @typeName(VariantType)),
        };
    }
};

pub const Command = struct {
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
    pub const Flags = packed struct {
        pub fn toAll(self: @This()) AllFlags {
            _ = self;
            return .{};
        }
    };

    pub fn deinit(_: *@This()) void {}
};

pub const Submenu = struct {
    menu_contents: *Contents = undefined,

    pub const Flags = packed struct {
        enabled: bool = true,

        pub fn toAll(self: @This()) AllFlags {
            return .{
                .enabled = self.enabled,
            };
        }
    };

    pub fn deinit(self: *@This()) void {
        self.menu_contents.deinit();
    }

    pub fn contents(self: *@This()) *Contents {
        return self.menu_contents;
    }
};

pub const Anchor = struct {
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

pub const InsertionLocation = union(enum) {
    before_: ?*Item,
    after_: ?*Item,
    replace_: *Item,

    pub const first = @This(){ .after_ = null };
    pub const last = @This(){ .before_ = null };

    pub fn before(any_item_ptr: anytype) @This() {
        return .{ .before_ = Item.fromAny(any_item_ptr) };
    }

    pub fn after(any_item_ptr: anytype) @This() {
        return .{ .after_ = Item.fromAny(any_item_ptr) };
    }

    /// NB. If replacing insertion fails, the old item is already removed
    /// (see Content.insertItem())
    pub fn replace(any_item_ptr: anytype) @This() {
        return .{ .replace_ = Item.fromAny(any_item_ptr) };
    }
};
