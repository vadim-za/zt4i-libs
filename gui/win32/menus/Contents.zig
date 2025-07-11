const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const item_types = @import("items.zig");
const debug = @import("../debug.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreatePopupMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;

extern "user32" fn AppendMenuW(
    hMenu: os.HMENU,
    uFlags: os.UINT,
    uIDNewItem: usize,
    lpNewItem: ?os.LPCWSTR,
) callconv(.winapi) os.BOOL;

extern "user32" fn InsertMenuW(
    hMenu: os.HMENU,
    uPosition: os.UINT,
    uFlags: os.UINT,
    uIDNewItem: usize,
    lpNewItem: ?os.LPCWSTR,
) callconv(.winapi) os.BOOL;

const MF_GRAYED: os.UINT = 1;
const MF_CHECKED: os.UINT = 8;
const MF_POPUP: os.UINT = 0x10;
const MF_SEPARATOR: os.UINT = 0x800;

const MF_BYCOMMAND: os.UINT = 0;
const MF_BYPOSITION: os.UINT = 0x400;

// ----------------------------------------------------------------

hMenu: os.HMENU,

arena: *std.heap.ArenaAllocator,

items: ItemsList = .{},

// 0 is reserved, values above 16 bits are incompatible to WM_COMMAND
next_item_id: u16 = 1,

// Nodes after this one do not have up to date 'visible_pos' field.
// If null, then none of the nodes have up to date `visible pos' field.
first_dirty_node: ?*ItemsList.Node = null,

const Self = @This();

const ItemsList = std.DoublyLinkedList(item_types.Item);

pub fn addCommand(
    self: *@This(),
    text: []const u8,
    flags: item_types.Command.Flags,
) gui.Error!*item_types.Command {
    const id = self.next_item_id;
    self.next_item_id += 1;

    const item = try self.addItem(
        "command",
        text,
        id,
        flags,
    );

    return &item.variant.command;
}

pub fn addSeparator(
    self: *@This(),
    flags: item_types.Separator.Flags,
) gui.Error!*item_types.Separator {
    const item = try self.addItem(
        "separator",
        null,
        0,
        flags,
    );

    return &item.variant.separator;
}

pub fn addSubmenu(
    self: *@This(),
    text: []const u8,
    flags: item_types.Submenu.Flags,
) gui.Error!*item_types.Submenu {
    const hMenu = CreatePopupMenu() orelse
        return gui.Error.OsApi;
    errdefer if (DestroyMenu(hMenu) == os.FALSE)
        debug.safeModePanic("Error destroying menu");

    const item = try self.addItem(
        "submenu",
        text,
        @intFromPtr(hMenu),
        flags,
    );
    // No errdefer needed here, as we're using arena allocator

    const alloc = self.arena.allocator();
    const submenu_contents = try alloc.create(@This());
    submenu_contents.* = .{
        .hMenu = hMenu,
        .arena = self.arena,
    };
    item.variant.submenu.contents = submenu_contents;
    return &item.variant.submenu;
}

fn addItem(
    self: *@This(),
    comptime variant_field: []const u8,
    text: ?[]const u8,
    uIDNewItem: usize,
    flags: anytype,
) gui.Error!*item_types.Item {
    const alloc = self.arena.allocator();
    const node = try alloc.create(ItemsList.Node);

    const text16 = if (text) |t|
        (std.unicode.wtf8ToWtf16LeAllocZ(
            alloc,
            t,
        ) catch |err| switch (err) {
            error.InvalidWtf8 => return gui.Error.Usage,
            error.OutOfMemory => |e| return e,
        })
    else
        std.unicode.utf8ToUtf16LeStringLiteral("");

    const pos = self.items.len;

    const item = &node.data;
    item.* = .{
        .pos = pos,
        .visible_pos = undefined,
        .text16 = text16,
        .uIDItem = uIDNewItem,
        .variant = @unionInit(item_types.Variant, variant_field, .{
            .flags = flags,
        }),
    };
    self.items.append(node);

    if (flags.visible) {
        const all_flags = flags.toAll();
        const uFlags: os.UINT =
            (if (all_flags.enabled) 0 else MF_GRAYED) |
            (if (all_flags.checked) MF_CHECKED else 0);

        if (AppendMenuW(
            self.hMenu,
            uFlags,
            uIDNewItem,
            text16,
        ) == os.FALSE)
            return gui.Error.OsApi;

        self.updateVisiblePositionsTo(node);
    }

    return item;
}

fn invalidateVisiblePositionsFrom(
    self: *@This(),
    from_node: *ItemsList.Node, // including this node
) void {
    if (self.first_dirty_node) |first_dirty| {
        if (from_node.data.pos < first_dirty.data.pos)
            self.first_dirty_node = from_node;
    } else {
        self.first_dirty_node = from_node;
    }
}

fn updateVisiblePositionsTo(
    self: *@This(),
    to_node: *ItemsList.Node, // including this node
) void {
    self.invalidateVisiblePositionsFrom(to_node);

    // First backtrack to the last known visible_pos
    var visible_pos = if (self.findPrecedingVisibleNode(to_node)) |n|
        n.data.visible_pos + 1
    else
        0;

    // Now go forward updating
    var node = self.first_dirty_node.?;
    while (true) : (node = node.next.?) {
        const item = &node.data;

        item.visible_pos = undefined;
        if (item.isVisible()) {
            item.visible_pos = visible_pos;
            visible_pos += 1;
        }

        if (node == to_node) break;
    }

    self.first_dirty_node = to_node.next;
}

fn findPrecedingVisibleNode(
    self: *const @This(),
    from_node: *ItemsList.Node,
) ?*ItemsList.Node {
    _ = self;

    var node = from_node.prev;
    while (node) |n| : (node = n.prev) {
        const item = &n.data;
        if (item.isVisible())
            return n;
    }

    return null;
}

test "All" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const hMenu = CreatePopupMenu().?;
    defer debug.expect(DestroyMenu(hMenu) != os.FALSE);

    var contents = @This(){
        .arena = &arena,
        .hMenu = hMenu,
    };

    _ = try contents.addCommand("Command 1", .{ .visible = false });
    _ = try contents.addCommand("Command 2", .{ .enabled = false });
}
