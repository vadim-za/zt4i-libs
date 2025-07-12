const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const item_types = @import("items.zig");
const debug = @import("../debug.zig");
const Context = @import("Context.zig");
const command_ids = @import("command_ids.zig");

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

extern "user32" fn DeleteMenu(
    hMenu: os.HMENU,
    uPosition: os.UINT,
    uFlags: os.UINT,
) callconv(.winapi) os.BOOL;

const MENUITEMINFOW = extern struct {
    cbSize: os.UINT = @sizeOf(@This()),
    fMask: os.UINT = 0,
    fType: os.UINT = 0,
    fState: os.UINT = 0,
    wID: os.UINT = 0,
    hSubMenu: ?os.HMENU = null,
    hbmpChecked: ?*anyopaque = null, // HBITMAP
    hbmpUnchecked: ?*anyopaque = null, // HBITMAP
    dwItemData: usize = 0,
    dwTypeData: ?os.LPWSTR = null,
    cch: os.UINT = 0,
    hbmpItem: ?*anyopaque = null, // HBITMAP
};

const MIIM_STATE: os.UINT = 1;
const MIIM_STRING: os.UINT = 0x40;

const MFS_CHECKED: os.UINT = 8;
const MFS_GRAYED: os.UINT = 3;

extern "user32" fn SetMenuItemInfoW(
    hMenu: os.HMENU,
    item: os.UINT,
    fByPosition: os.BOOL,
    lpmii: *MENUITEMINFOW,
) callconv(.winapi) os.BOOL;

// ----------------------------------------------------------------

hMenu: os.HMENU,

context: *Context,
items_alloc: std.mem.Allocator,

items: ItemsList = .{},

// This and the following nodes do not have up to date 'visible_pos' field.
// If null, then all nodes are up to date.
first_dirty_node: ?*ItemsList.Node = null,

const Self = @This();

const ItemsList = std.DoublyLinkedList(item_types.Item);

/// Can be called repeatedly
pub fn deinit(self: *@This()) void {
    while (self.items.pop()) |node| {
        const item = &node.data;
        item.deinit();
        self.items_alloc.destroy(node);
    }
}

// The max_id is defined in command_ids.zig

/// Allowed 'id' range is 0..60000 (not including the upper bound).
/// The range is limited due to OS limitations and potentially may
/// become even smaller, so try to use as small id values as possible.
///
/// The formal type of 'id' is usize, so that the caller doesn't need
/// to use @intCast(), instead addCommand will return gui.Error.Usage
/// for out-of-range ids.
///
/// Be careful of reusing the id values in menu modifications, there
/// may be subtle asynchronisity in menu notifications sent from the OS,
/// so (however unlikely) you potentially might receive a command
/// notification from a command which has been deleted and recreated
/// with the same id but new semantics.
pub fn addCommand(
    self: *@This(),
    where: item_types.Where,
    text: []const u8,
    id: usize,
    flags: item_types.Command.Flags,
) gui.Error!*item_types.Command {
    const item = try self.insertItem(
        where,
        .command,
        text,
        command_ids.toOsId(id) orelse return gui.Error.Usage,
        flags,
    );

    return &item.variant.command;
}

pub fn addSeparator(
    self: *@This(),
    where: item_types.Where,
) gui.Error!*item_types.Separator {
    const item = try self.insertItem(
        where,
        .separator,
        null,
        0,
        .{},
    );

    return &item.variant.separator;
}

pub fn addSubmenu(
    self: *@This(),
    where: item_types.Where,
    text: []const u8,
    flags: item_types.Submenu.Flags,
    items_alloc: ?std.mem.Allocator,
) gui.Error!*item_types.Submenu {
    const hMenu = CreatePopupMenu() orelse
        return gui.Error.OsApi;
    errdefer if (DestroyMenu(hMenu) == os.FALSE)
        debug.safeModePanic("Error destroying menu");

    const item = try self.insertItem(
        where,
        .submenu,
        text,
        @intFromPtr(hMenu),
        flags,
    );

    item.variant.submenu.contents = .{
        .hMenu = hMenu,
        .context = self.context,
        .items_alloc = items_alloc orelse self.items_alloc,
    };

    return &item.variant.submenu;
}

pub fn addAnchor(
    self: *@This(),
    where: item_types.Where,
) gui.Error!*item_types.Anchor {
    const item = try self.insertItem(
        where,
        .anchor,
        null,
        0,
        .{},
    );

    return &item.variant.anchor;
}

fn insertItem(
    self: *@This(),
    where: item_types.Where,
    comptime variant_tag: std.meta.Tag(item_types.Variant),
    text: ?[]const u8,
    uIDNewItem: usize,
    flags: @FieldType(item_types.Variant, @tagName(variant_tag)).Flags,
) gui.Error!*item_types.Item {
    const node = try self.items_alloc.create(ItemsList.Node);
    errdefer self.items_alloc.destroy(node);

    const index = self.items.len;

    const item = &node.data;
    item.* = .{
        .index = index,
        .visible_pos = undefined,
        .variant = @unionInit(
            item_types.Variant,
            @tagName(variant_tag),
            .{
                .flags = flags, // do we need to store the flags?
            },
        ),
    };

    // 'null' means 'append'
    const insert_before: ?*ItemsList.Node = switch (where.ordered) {
        .before => if (where.reference_item) |ref|
            nodeFromItem(@constCast(ref))
        else
            self.items.last,
        .after => if (where.reference_item) |ref|
            nodeFromItem(@constCast(ref)).next
        else
            self.items.first,
    };

    if (insert_before) |ib|
        self.items.insertBefore(ib, node)
    else
        self.items.append(node);
    errdefer self.items.remove(node);

    if (item.isVisible()) {
        const all_flags = flags.toAll();
        const uFlags: os.UINT =
            (if (all_flags.enabled) 0 else MF_GRAYED) |
            (if (all_flags.checked) MF_CHECKED else 0);
        const text16 = if (text) |t|
            try self.context.convertU8(t)
        else
            std.unicode.utf8ToUtf16LeStringLiteral("");

        if (insert_before) |ib| {
            const pos = self.getVisiblePos(ib);
            if (InsertMenuW(
                self.hMenu,
                @intCast(pos),
                uFlags | MF_BYPOSITION,
                uIDNewItem,
                text16.ptr,
            ) == os.FALSE)
                return gui.Error.OsApi;
        } else {
            if (AppendMenuW(
                self.hMenu,
                uFlags,
                uIDNewItem,
                text16.ptr,
            ) == os.FALSE)
                return gui.Error.OsApi;
        }

        self.updateVisiblePositions(node);
    }

    return item;
}

pub fn deleteItem(self: *@This(), any_item_ptr: anytype) void {
    const item = item_types.Item.fromAny(any_item_ptr);
    const node = nodeFromItem(item);

    if (item.isVisible()) {
        const pos = self.getVisiblePos(node);
        if (DeleteMenu(
            self.hMenu,
            @intCast(pos),
            MF_BYPOSITION,
        ) == os.FALSE)
            debug.debugModePanic("Deleting menu item failed");
    }

    const next_node = node.next;
    self.items.remove(node);
    if (next_node) |nn|
        self.invalidateVisiblePositionsFrom(nn);

    self.items_alloc.destroy(node);
}

pub fn modifyItem(
    self: *@This(),
    any_item_ptr: anytype,
    text: ?[]const u8,
    flags: ?@TypeOf(any_item_ptr.*).Flags,
) gui.Error!void {
    const item = item_types.Item.fromAny(any_item_ptr);
    const node = nodeFromItem(item);

    if (item.isVisible()) {
        const pos = self.getVisiblePos(node);

        const text16: ?[*:0]const u16 = if (text) |t|
            (try self.context.convertU8(t)).ptr
        else
            null;

        const all_flags: ?item_types.AllFlags =
            if (flags) |f| f.toAll() else null;
        const fState: os.UINT = if (all_flags) |f|
            (if (f.enabled) 0 else MFS_GRAYED) |
                (if (f.checked) MFS_CHECKED else 0)
        else
            0;

        var mii = MENUITEMINFOW{
            .fMask = (if (text16 != null) MIIM_STRING else 0) |
                (if (all_flags != null) MIIM_STATE else 0),
            .fState = fState,
            .dwTypeData = @constCast(text16),
        };

        if (SetMenuItemInfoW(
            self.hMenu,
            @intCast(pos),
            os.TRUE,
            &mii,
        ) == os.FALSE)
            debug.debugModePanic("Modifying menu item failed");
    }
}

/// May be called only if node.data.isVisible() is true
fn getVisiblePos(
    self: *@This(),
    node: *ItemsList.Node,
) usize {
    if (std.debug.runtime_safety)
        std.debug.assert(node.data.isVisible());

    if (self.first_dirty_node) |first_dirty| {
        if (node.data.index >= first_dirty.data.index)
            self.updateVisiblePositions(node);
    }

    return node.data.visible_pos;
}

/// Invalidates all visible positions starting from and
/// including 'from_node'
fn invalidateVisiblePositionsFrom(
    self: *@This(),
    from_node: *ItemsList.Node,
) void {
    if (self.first_dirty_node) |first_dirty| {
        if (from_node.data.index < first_dirty.data.index)
            self.first_dirty_node = from_node;
    } else {
        self.first_dirty_node = from_node;
    }
}

/// Updates all visible positions up to and including
/// 'up_to_node'. Invalidates all following positions.
fn updateVisiblePositions(
    self: *@This(),
    up_to_node: *ItemsList.Node,
) void {
    // We also want to recompute the visible_pos for up_to_node.
    self.invalidateVisiblePositionsFrom(up_to_node);

    // First backtrack to the last known visible_pos
    var visible_pos =
        if (self.findPrecedingUpToDateVisibleNode(up_to_node)) |n|
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

        if (node == up_to_node) break;
    }

    self.first_dirty_node = up_to_node.next;
}

fn findPrecedingUpToDateVisibleNode(
    self: *const @This(),
    node: *ItemsList.Node,
) ?*ItemsList.Node {
    var it_node = node;
    if (self.first_dirty_node) |first_dirty| {
        if (it_node.data.index > first_dirty.data.index)
            it_node = first_dirty;
    }

    while (true) {
        it_node = it_node.prev orelse
            return null;
        const item = &it_node.data;
        if (item.isVisible())
            return it_node;
    }
}

fn nodeFromItem(item: *item_types.Item) *ItemsList.Node {
    return @alignCast(@fieldParentPtr("data", item));
}

test "All" {
    const winmain = @import("../winmain.zig");
    winmain.test_startup.init();
    defer winmain.test_startup.deinit();

    var context: Context = undefined;
    try context.init();
    defer context.deinit();

    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const hMenu = CreatePopupMenu().?;
    defer debug.expect(DestroyMenu(hMenu) != os.FALSE);

    var contents = @This(){
        .hMenu = hMenu,
        .context = &context,
        .items_alloc = arena.allocator(),
    };

    _ = try contents.addAnchor();
    _ = try contents.addCommand("Command 1", 0, .{});
    _ = try contents.addSeparator();
    _ = try contents.addCommand("Command 2", 1, .{ .enabled = false });
}
