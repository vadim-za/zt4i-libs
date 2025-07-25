const std = @import("std");
const os = std.os.windows;

const DefaultAllocator = @import("DefaultAllocator.zig");
const message_box = @import("message_box.zig");
const dpi = @import("dpi.zig");
const window_class = @import("window/class.zig");
const directx = @import("directx.zig");

const WWinMain = fn (
    hInst: ?os.HINSTANCE,
    _: ?os.HINSTANCE,
    _: ?os.LPCWSTR,
    _: os.INT,
) os.INT;

// See DefaultAllocator for the expectations to the Allocator type
pub fn wWinMain(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
    app_icon_id: ?usize,
    Allocator: ?type,
) WWinMain {
    return struct {
        fn wWinMainGeneric(
            hInst: ?os.HINSTANCE,
            _: ?os.HINSTANCE,
            _: ?os.LPCWSTR,
            _: os.INT,
        ) os.INT {
            return wWinMainImpl(
                app_title,
                mainFunc,
                app_icon_id,
                Allocator,
                hInst,
            );
        }
    }.wWinMainGeneric;
}

// ----------------------------------------------------------

var this_instance: ?os.HINSTANCE = null;

pub fn thisInstance() os.HINSTANCE {
    return this_instance.?;
}

var main_thread: ?std.Thread.Id = null;

pub inline fn assertMainThread() std.Thread.Id {
    if (std.debug.runtime_safety)
        std.debug.assert(std.Thread.getCurrentId() == main_thread.?);
}

var global_allocator: ?std.mem.Allocator = null;

pub fn allocator() std.mem.Allocator {
    return global_allocator.?;
}

var panicking = false;

pub fn enterPanicMode() void {
    panicking = true;
}

pub inline fn isPanicMode() bool {
    return panicking;
}

fn wWinMainImpl(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
    app_icon_id: ?usize,
    Allocator: ?type,
    hInst: ?os.HINSTANCE,
) os.INT {
    this_instance = hInst;

    main_thread = std.Thread.getCurrentId();
    defer main_thread = null;

    const AllocatorObject = Allocator orelse DefaultAllocator;
    var allocator_object: AllocatorObject = undefined;
    allocator_object.init() catch
        return failStartup(app_title, "initialize allocator");
    defer allocator_object.deinit();

    global_allocator = allocator_object.allocator();

    dpi.setupDpiAwareness() catch
        return failStartup(app_title, "set DPI awareness");

    directx.init() catch
        return failStartup(app_title, "initialize DirectX");
    defer directx.deinit();

    window_class.registerClass(app_icon_id) catch
        return failStartup(app_title, "register window class");
    defer (window_class.unregisterClass() catch {});

    mainFunc();

    return 0;
}

fn failStartup(
    comptime app_title: []const u8,
    comptime what: []const u8,
) os.INT {
    _ = message_box.showComptime(
        null,
        app_title,
        "Could not " ++ what,
        .ok,
    ) catch {}; // we are already failing, ignore further errors
    return 0;
}

// --------------------------------------------------------------------------

pub const test_startup = struct {
    pub fn init() void {
        std.debug.assert(global_allocator == null);
        global_allocator = std.testing.allocator;
    }
    pub fn deinit() void {
        std.debug.assert(std.mem.order(
            u8,
            std.mem.asBytes(&global_allocator.?),
            std.mem.asBytes(&std.testing.allocator),
        ) == .eq);
        global_allocator = null;
    }
};
