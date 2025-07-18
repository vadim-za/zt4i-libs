const std = @import("std");
const builtin = @import("builtin");
const lib = @import("../../lib.zig");
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

// Items up to this one inclusively have up to date 'index' and
// 'visible_pos' fields. If null, then all nodes are not up to date.
last_nondirty_item: ?*item_types.Item = null,

const Self = @This();

/// Can be called repeatedly
pub fn deinit(self: *@This()) void {
    while (self.items.popLast()) |item| {
        item.deinit();
        self.context.contents_pool.destroy(item);
    }
}

// The max_id is defined in command_ids.zig

/// Allowed 'id' range is 0..60000 (not including the upper bound).
/// The range is limited due to OS limitations and potentially may
/// become even smaller, so try to use as small id values as possible.
/// For larger menus it might be a good idea to organize an array stack
/// of command handling closures and use array indices as command ids.
///
/// The formal type of 'id' is usize, so that the caller doesn't need
/// to use @intCast(), instead addCommand will return lib.Error.Usage
/// for out-of-range ids.
///
/// Be careful of reusing the id values in menu modifications, there
/// may be subtle asynchronisity in menu notifications sent from the OS,
/// so (however unlikely) you potentially might receive a command
/// notification from a command which has been deleted and recreated
/// with the same id but new semantics.
pub fn addCommand(
    self: *@This(),
    where: item_types.InsertionLocation,
    text: []const u8,
    id: usize,
) lib.Error!*item_types.Command {
    const item = try self.insertItem(
        where,
        .command,
        text,
        command_ids.toOsId(id) orelse return lib.Error.Usage,
    );

    return &item.variant.command;
}

pub fn addSeparator(
    self: *@This(),
    where: item_types.InsertionLocation,
) lib.Error!*item_types.Separator {
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
    where: item_types.InsertionLocation,
    text: []const u8,
) lib.Error!*item_types.Submenu {
    const submenu_contents =
        try self.context.contents_pool.create(Contents);
    errdefer self.context.contents_pool.destroy(submenu_contents);

    const hMenu = CreatePopupMenu() orelse
        return lib.Error.OsApi;
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
    where: item_types.InsertionLocation,
) lib.Error!*item_types.Anchor {
    const item = try self.insertItem(
        where,
        .anchor,
        null,
        0,
    );

    return &item.variant.anchor;
}

// NB. If replacing insertion fails, the old item is already removed.
// See InsertionLocation.replace() for public docs.
fn insertItem(
    self: *@This(),
    where: item_types.InsertionLocation,
    comptime variant_tag: std.meta.Tag(item_types.Variant),
    text: ?[]const u8,
    uIDNewItem: usize,
) lib.Error!*item_types.Item {
    // 'null' means 'prepend'
    const insert_after: ?*item_types.ItemsList.Node =
        switch (where) {
            .before_ => |ref_item| if (ref_item) |ref|
                self.items.prev(ref)
            else
                self.items.last(),
            .after_ => |ref_item| if (ref_item) |ref|
                ref
            else
                null,
            .replace_ => |old_item| repl: {
                const prev = self.items.prev(old_item);
                self.deleteRawItem(old_item);
                break :repl prev;
            },
        };

    const index, const visible_pos = if (insert_after) |ia| ia: {
        // Safe to call updateDirtyNodes(ia), since we didn't modify
        // the items list yet.
        self.updateDirtyItems(ia);
        break :ia .{ ia.index + 1, ia.nextVisiblePos() };
    } else .{ 0, 0 };

    const item = try self.context.contents_pool.create(
        item_types.Item,
    );
    errdefer self.context.contents_pool.destroy(item);

    item.* = .{
        .index = index,
        .visible_pos = visible_pos,
        .variant = @unionInit(
            item_types.Variant,
            @tagName(variant_tag),
            .{},
        ),
        .list_hook = undefined,
        .owner = if (std.debug.runtime_safety) self,
    };

    if (insert_after) |ia|
        self.items.insertAfter(ia, item)
    else
        self.items.insertFirst(item);
    errdefer self.items.remove(item);

    // The items preceding 'item' are up-to-date due to the
    // updateDirtyItems() call earlier above. The 'item' has
    // been set up to date manually.
    self.last_nondirty_item = item;

    if (item.isVisible()) {
        const text16: ?[*:0]const u16 = if (text) |t|
            (try self.context.convertU8(t)).ptr
        else
            null;

        const uFlags: os.UINT = switch (variant_tag) {
            .submenu => MF_POPUP,
            .separator => MF_SEPARATOR,
            else => 0,
        };

        if (item == self.items.last()) {
            if (AppendMenuW(
                self.hMenu,
                uFlags,
                uIDNewItem,
                text16,
            ) == os.FALSE)
                return lib.Error.OsApi;
        } else {
            if (InsertMenuW(
                self.hMenu,
                @intCast(visible_pos),
                uFlags | MF_BYPOSITION,
                uIDNewItem,
                text16,
            ) == os.FALSE)
                return lib.Error.OsApi;
        }
    }

    return item;
}

pub fn deleteItem(self: *@This(), any_item_ptr: anytype) void {
    self.deleteRawItem(item_types.Item.fromAny(any_item_ptr));
}

fn deleteRawItem(self: *@This(), item: *item_types.Item) void {
    // Safe to call updateDirtyItems(item), since
    // we didn't modify the items list yet.
    self.updateDirtyItems(item);

    if (item.isVisible()) {
        const pos = item.visible_pos;

        if (DeleteMenu(
            self.hMenu,
            @intCast(pos),
            MF_BYPOSITION,
        ) == os.FALSE)
            debug.debugModePanic("Deleting menu item failed");
    }

    // The items preceding the 'item' (inclusively) are up-to-date
    // due to the updateDirtyItems() call earlier above.
    // So we can simply set the last nondirty item to prev(item).
    self.last_nondirty_item = self.items.prev(item);

    self.items.remove(item);
    self.context.contents_pool.destroy(item);
}

pub fn modifyCommand(
    self: *@This(),
    command: *item_types.Command,
    text: ?[]const u8,
    flags: ?item_types.Command.Flags,
) lib.Error!void {
    try self.modifyItem(command, text, flags);
}

pub fn modifySubmenu(
    self: *@This(),
    submenu: *item_types.Submenu,
    text: ?[]const u8,
    flags: ?item_types.Submenu.Flags,
) lib.Error!void {
    try self.modifyItem(submenu, text, flags);
}

fn modifyItem(
    self: *@This(),
    any_item_ptr: anytype,
    text: ?[]const u8,
    flags: ?@TypeOf(any_item_ptr.*).Flags,
) lib.Error!void {
    const item = item_types.Item.fromAny(any_item_ptr);

    if (item.isVisible()) {
        // Safe to call updateDirtyItems(item), since
        // we didn't modify the items list yet.
        self.updateDirtyItems(item);
        const pos = item.visible_pos;

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
/// since the last time `first_dirty_item' field has been updated.
/// Updates all items up to and including 'up_to_item'.
fn updateDirtyItems(
    self: *@This(),
    up_to_item: *item_types.ItemsList.Node,
) void {
    var item, var index, var visible_pos =
        if (self.last_nondirty_item) |lni| lni: {
            if (up_to_item.index > lni.index)
                break :lni .{
                    self.items.next(lni),
                    lni.index + 1,
                    lni.nextVisiblePos(),
                }
            else
                return;
        } else .{ self.items.first(), 0, 0 };

    // Actually we could simply do while(true), since the loop
    // is supposed to break on comparison against 'up_to_item'.
    // But we still check node defensively against null.
    while (item) |it| {
        it.index = index;
        it.visible_pos = visible_pos;

        // Since we checked that 'up_to_item' does not occur earlier
        // in the list than 'first_dirty_item', we expect that the
        // loop terminates here.
        if (it == up_to_item) break;

        item = self.items.next(it);
        index += 1;
        visible_pos = it.nextVisiblePos();
    }

    // Use '.?' to cause panic if we didn't encounter 'up_to_item'
    self.last_nondirty_item = item.?;
}

// TODO: unit tests for position updating
