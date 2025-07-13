const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../../gui.zig");
const item_types = @import("items.zig");
const debug = @import("../debug.zig");
const Context = @import("Context.zig");
const Contents = @import("Contents.zig");
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

items: item_types.ItemsList = .{},

// Nodes up to this one inclusively have up to date 'index' and
// 'visible_pos' fields. If null, then all nodes are not up to date.
last_nondirty_node: ?*item_types.ItemsList.Node = null,

const Self = @This();

/// Can be called repeatedly
pub fn deinit(self: *@This()) void {
    while (self.items.pop()) |node| {
        const item = &node.data;
        item.deinit();
        self.context.contents_pool.destroy(node);
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
) gui.Error!*item_types.Command {
    const item = try self.insertItem(
        where,
        .command,
        text,
        command_ids.toOsId(id) orelse return gui.Error.Usage,
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
    );

    return &item.variant.separator;
}

pub fn addSubmenu(
    self: *@This(),
    where: item_types.Where,
    text: []const u8,
) gui.Error!*item_types.Submenu {
    const submenu_contents =
        try self.context.contents_pool.create(Contents);
    errdefer self.context.contents_pool.destroy(submenu_contents);

    const hMenu = CreatePopupMenu() orelse
        return gui.Error.OsApi;
    errdefer if (DestroyMenu(hMenu) == os.FALSE)
        debug.safeModePanic("Error destroying menu");

    const item = try self.insertItem(
        where,
        .submenu,
        text,
        @intFromPtr(hMenu),
    );

    submenu_contents.* = .{
        .hMenu = hMenu,
        .context = self.context,
    };
    item.variant.submenu.menu_contents = submenu_contents;

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
    );

    return &item.variant.anchor;
}

fn insertItem(
    self: *@This(),
    where: item_types.Where,
    comptime variant_tag: std.meta.Tag(item_types.Variant),
    text: ?[]const u8,
    uIDNewItem: usize,
) gui.Error!*item_types.Item {
    // 'null' means 'prepend'
    const insert_after: ?*item_types.ItemsList.Node =
        switch (where.ordered) {
            .before => if (where.reference_item) |ref|
                nodeFromItem(ref).prev
            else
                self.items.last,
            .after => if (where.reference_item) |ref|
                nodeFromItem(ref)
            else
                null,
        };

    const index, const visible_pos = if (insert_after) |ia| ia: {
        // Safe to call updateDirtyNodes(ia), since we didn't modify
        // the items list yet.
        self.updateDirtyNodes(ia);
        break :ia .{ ia.data.index + 1, ia.data.nextVisiblePos() };
    } else .{ 0, 0 };

    const node = try self.context.contents_pool.create(
        item_types.ItemsList.Node,
    );
    errdefer self.context.contents_pool.destroy(node);

    const item = &node.data;
    item.* = .{
        .index = index,
        .visible_pos = visible_pos,
        .variant = @unionInit(
            item_types.Variant,
            @tagName(variant_tag),
            .{},
        ),
    };

    if (insert_after) |ia|
        self.items.insertAfter(ia, node)
    else
        self.items.prepend(node);
    errdefer self.items.remove(node);

    // The nodes preceding 'node' are up-to-date due to the
    // updateDirtyNodes() call earlier above. The 'node' has
    // been set up to date manually.
    self.last_nondirty_node = node;

    if (item.isVisible()) {
        const text16 = if (text) |t|
            try self.context.convertU8(t)
        else
            std.unicode.utf8ToUtf16LeStringLiteral("");

        const uFlags: os.UINT = if (variant_tag == .submenu)
            MF_POPUP
        else
            0;

        if (node == self.items.last) {
            if (AppendMenuW(
                self.hMenu,
                uFlags,
                uIDNewItem,
                text16.ptr,
            ) == os.FALSE)
                return gui.Error.OsApi;
        } else {
            if (InsertMenuW(
                self.hMenu,
                @intCast(visible_pos),
                uFlags | MF_BYPOSITION,
                uIDNewItem,
                text16.ptr,
            ) == os.FALSE)
                return gui.Error.OsApi;
        }
    }

    return item;
}

pub fn deleteItem(self: *@This(), any_item_ptr: anytype) void {
    const item = item_types.Item.fromAny(any_item_ptr);
    const node = nodeFromItem(item);

    // Safe to call updateDirtyNodes(node), since
    // we didn't modify the items list yet.
    self.updateDirtyNodes(node);

    if (item.isVisible()) {
        const pos = node.data.visible_pos;

        if (DeleteMenu(
            self.hMenu,
            @intCast(pos),
            MF_BYPOSITION,
        ) == os.FALSE)
            debug.debugModePanic("Deleting menu item failed");
    }

    // The nodes preceding the 'node' (inclusively) are up-to-date
    // due to the updateDirtyNodes() call earlier above.
    // So we can simply set the last nondirty node to node.prev.
    self.last_nondirty_node = node.prev;

    self.items.remove(node);
    self.context.contents_pool.destroy(node);
}

pub fn modifyCommand(
    self: *@This(),
    command: *item_types.Command,
    text: ?[]const u8,
    flags: ?item_types.Command.Flags,
) gui.Error!void {
    try self.modifyItem(command, text, flags);
}

pub fn modifySubmenu(
    self: *@This(),
    submenu: *item_types.Submenu,
    text: ?[]const u8,
    flags: ?item_types.Submenu.Flags,
) gui.Error!void {
    try self.modifyItem(submenu, text, flags);
}

fn modifyItem(
    self: *@This(),
    any_item_ptr: anytype,
    text: ?[]const u8,
    flags: ?@TypeOf(any_item_ptr.*).Flags,
) gui.Error!void {
    const item = item_types.Item.fromAny(any_item_ptr);
    const node = nodeFromItem(item);

    if (item.isVisible()) {
        // Safe to call updateDirtyNodes(node), since
        // we didn't modify the items list yet.
        self.updateDirtyNodes(node);
        const pos = node.data.visible_pos;

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

/// May be called only if the list hasn't been manipulated
/// since the last time `first_dirty_node' field has been updated.
/// Updates all nodes up to and including 'up_to_node'.
fn updateDirtyNodes(
    self: *@This(),
    up_to_node: *item_types.ItemsList.Node,
) void {
    var node, var index, var visible_pos =
        if (self.last_nondirty_node) |lnn| lnn: {
            if (up_to_node.data.index > lnn.data.index)
                break :lnn .{
                    lnn.next,
                    lnn.data.index + 1,
                    lnn.data.nextVisiblePos(),
                }
            else
                return;
        } else .{ self.items.first, 0, 0 };

    // Actually we could simply do while(true), since the loop
    // is supposed to break on comparison against 'up_to_node'.
    // But we still check node defensively against null.
    while (node) |n| {
        const item = &n.data;

        item.index = index;
        item.visible_pos = visible_pos;

        // Since we checked that 'up_to_node' does not occur earlier
        // in the list than 'first_dirty_node', we expect that the
        // loop terminates here.
        if (n == up_to_node) break;

        node = n.next;
        index += 1;
        visible_pos = item.nextVisiblePos();
    }

    // Use '.?' to cause panic if we didn't encounter 'up_to_node'
    self.last_nondirty_node = node.?;
}

fn nodeFromItem(item: *item_types.Item) *item_types.ItemsList.Node {
    return @alignCast(@fieldParentPtr("data", item));
}

// TODO: unit tests for position updating
