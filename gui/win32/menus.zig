const std = @import("std");
const builtin = @import("builtin");
const gui = @import("../gui.zig");
const unicode = @import("unicode.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

extern "user32" fn CreatePopupMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn CreateMenu() callconv(.winapi) ?os.HMENU;
extern "user32" fn DestroyMenu(hMenu: os.HMENU) callconv(.winapi) os.BOOL;
extern "user32" fn AppendMenuW(
    hMenu: os.HMENU,
    uFlags: os.UINT,
    uIDNewItem: usize,
    lpNewItem: ?os.LPCWSTR,
) callconv(.winapi) os.BOOL;
extern "user32" fn EnableMenuItem(
    hMenu: os.HMENU,
    uIDEnableItem: os.UINT,
    uEnable: os.UINT,
) callconv(.winapi) os.BOOL;
extern "user32" fn CheckMenuItem(
    hMenu: os.HMENU,
    uIDCheckItem: os.UINT,
    uCheck: os.DWORD,
) callconv(.winapi) os.BOOL;
extern "user32" fn ModifyMenuW(
    hMenu: os.HMENU,
    uPosition: os.UINT,
    uFlags: os.UINT,
    uIDNewItem: usize,
    lpNewItem: ?os.LPCWSTR,
) callconv(.winapi) os.BOOL;
extern "user32" fn GetMenu(
    hWnd: os.HWND,
) callconv(.winapi) ?os.HMENU;
extern "user32" fn SetMenu(
    hWnd: os.HWND,
    hMenu: ?os.HMENU,
) callconv(.winapi) os.BOOL;

pub const MF_GRAYED: os.UINT = 0x1;
pub const MF_CHECKED: os.UINT = 0x8;
pub const MF_POPUP: os.UINT = 0x10;

extern "user32" fn GetCursorPos(*os.POINT) callconv(.winapi) os.BOOL;
extern "user32" fn TrackPopupMenu(
    hMenu: os.HMENU,
    uFlags: os.UINT,
    x: c_int,
    y: c_int,
    nReserved: c_int,
    hWnd: os.HWND,
    prcRect: ?*const os.RECT,
) callconv(.winapi) c_int;

pub const TPM_RIGHTBUTTON: os.UINT = 2;
pub const TPM_NONOTIFY: os.UINT = 0x80;
pub const TPM_RETURNCMD: os.UINT = 0x100;

// ----------------------------------------------------------------

const os_item_base_id = 1;

fn toOsItemId(id: anytype) u32 {
    const raw_id: u32 = switch (@typeInfo(@TypeOf(id))) {
        .int, .comptime_int => @intCast(id),
        .@"enum" => @intFromEnum(id), // enum literals must be explicitly type-qualified
        else => unreachable,
    };
    const os_id: u31 = @intCast(os_item_base_id + raw_id); // must fit into 31 bits
    return os_id;
}

pub fn fromOsItemId(os_id: u32) u32 {
    return @intCast(os_id - os_item_base_id);
}

// ----------------------------------------------------------------

// Menu bar
pub const Bar = struct {
    hMenu: ?os.HMENU = null,

    pub fn deinit(self: *@This()) void {
        if (self.hMenu) |hMenu| {
            destroyMenuExpectSuccess(hMenu);
            self.hMenu = null;
        }
    }
};

// Popup menu
pub const Popup = struct {
    hMenu: ?os.HMENU = null,

    pub fn deinit(self: *@This()) void {
        if (self.hMenu) |hMenu| {
            destroyMenuExpectSuccess(hMenu);
            self.hMenu = null;
        }
    }

    pub fn runWithinWindow(
        self: *@This(),
        window: *gui.Window,
    ) gui.Error!?u32 {
        var pt: os.POINT = undefined;
        if (GetCursorPos(&pt) == os.FALSE)
            return gui.Error.OsApi;

        const nResult = TrackPopupMenu(
            self.hMenu.?,
            TPM_NONOTIFY | TPM_RETURNCMD | TPM_RIGHTBUTTON,
            pt.x,
            pt.y,
            0,
            window.hWnd.?,
            null,
        );
        if (nResult > 0)
            return fromOsItemId(@intCast(nResult));
        return null;
    }
};

pub const EditorContext = struct {
    str16: unicode.Wtf16Str(500),

    pub fn init(self: *@This()) void {
        self.str16.init();
    }

    pub fn deinit(self: *@This()) void {
        self.str16.deinit();
    }

    fn convertU8(self: *@This(), str8: []const u8) gui.Error![*:0]const u16 {
        try self.str16.setU8(str8);
        return self.str16.ptr();
    }

    pub fn createBar(self: *@This()) gui.Error!BarCreator {
        return if (CreateMenu()) |hMenu| .{
            .context = self,
            .hMenu = hMenu,
        } else gui.Error.OsApi;
    }

    pub fn createPopup(self: *@This()) gui.Error!PopupCreator {
        return if (CreatePopupMenu()) |hMenu| .{
            .context = self,
            .hMenu = hMenu,
        } else gui.Error.OsApi;
    }
};

pub const BarCreator = struct {
    context: *EditorContext,
    hMenu: os.HMENU,

    pub fn editor(self: *@This()) Editor {
        return .{ .context = self.context, .hMenu = self.hMenu };
    }

    // You must call either abort or close

    pub fn abort(self: *@This()) void {
        destroyMenuExpectSuccess(self.hMenu);
        self.* = undefined;
    }

    pub fn close(self: *@This()) gui.Error!Bar {
        defer self.* = undefined;
        return .{ .hMenu = self.hMenu };
    }
};

pub const PopupCreator = struct {
    context: *EditorContext,
    hMenu: os.HMENU,

    pub fn editor(self: *@This()) Editor {
        return .{ .context = self.context, .hMenu = self.hMenu };
    }

    // You must call either abort or close

    pub fn abort(self: *@This()) void {
        destroyMenuExpectSuccess(self.hMenu);
        self.* = undefined;
    }

    pub fn close(self: *@This()) gui.Error!Popup {
        defer self.* = undefined;
        return .{ .hMenu = self.hMenu };
    }
};

pub const SubCreator = struct {
    context: *EditorContext,
    hMenu: os.HMENU,
    hParentMenu: os.HMENU,
    text: []const u8,

    pub fn editor(self: *@This()) Editor {
        return .{ .context = self.context, .hMenu = self.hMenu };
    }

    // You must call either abort or close

    pub fn abort(self: *@This()) void {
        destroyMenuExpectSuccess(self.hMenu);
        self.* = undefined;
    }

    pub fn close(self: *@This()) gui.Error!void {
        const text16 = try self.context.convertU8(self.text);
        if (AppendMenuW(
            self.hParentMenu,
            MF_POPUP,
            @intFromPtr(self.hMenu),
            text16,
        ) == os.FALSE) return gui.Error.OsApi;

        self.* = undefined;
    }
};

pub const ItemFlags = packed struct {
    enabled: bool = true,
    checked: bool = false,

    fn toOsFlags(self: @This()) os.UINT {
        var uFlags: os.UINT = 0;
        if (!self.enabled) uFlags |= MF_GRAYED;
        if (self.checked) uFlags |= MF_CHECKED;

        return uFlags;
    }
};

pub const Editor = struct {
    context: *EditorContext,
    hMenu: os.HMENU,

    pub fn addCommand(
        self: *@This(),
        text: []const u8,
        id: anytype,
    ) gui.Error!void {
        const uItemID = toOsItemId(id);
        const text16 = try self.context.convertU8(text);
        if (AppendMenuW(
            self.hMenu,
            0,
            uItemID,
            text16,
        ) == os.FALSE) return gui.Error.OsApi;
    }

    pub fn modifyCommand(
        self: *@This(),
        id: anytype,
        text: []const u8,
        flags: ItemFlags,
    ) gui.Error!void {
        const uItemID = toOsItemId(id);
        const uFlags = flags.toOsFlags();
        const text16 = try self.context.convertU8(text);
        if (ModifyMenuW(
            self.hMenu,
            uItemID,
            uFlags,
            uItemID,
            text16,
        ) == os.FALSE) return gui.Error.OsApi;
    }
};

fn destroyMenuExpectSuccess(hMenu: os.HMENU) void {
    if (DestroyMenu(hMenu) == os.FALSE and builtin.mode == .Debug)
        @panic("Failed to destroy menu");
}

// scratchpad
fn testMenu() void {
    var ctx: EditorContext = undefined;
    ctx.init();
    defer ctx.deinit();

    var bar_creator = try ctx.createBar();
    errdefer bar_creator.abort();
    {
        errdefer bar_creator.abort();
        var bar = bar_creator.editor();
        try bar.addCommand("Text", 1, .{});
        var edit_creator = try bar.addSub("Edit");
        {
            errdefer edit_creator.abort();
            var edit = edit_creator.editor();
            try edit.addCommand("Text", 1, .{});
        }
        try edit_creator.close();
    }
    var menu_bar = try bar_creator.close();

    _ = &menu_bar;
}
