const std = @import("std");
const os = std.os.windows;

const DefaultAllocator = @import("DefaultAllocator.zig");
const message_box = @import("message_box.zig");

const WWinMain = fn (
    hInst: ?os.HINSTANCE,
    _: ?os.HINSTANCE,
    _: ?os.LPCWSTR,
    _: os.INT,
) os.INT;

pub fn wWinMain(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
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

var global_allocator: ?std.mem.Allocator = null;

pub fn allocator() std.mem.Allocator {
    return global_allocator.?;
}

fn wWinMainImpl(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
    Allocator: ?type,
    hInst: ?os.HINSTANCE,
) os.INT {
    this_instance = hInst;

    const AllocatorObject = Allocator orelse DefaultAllocator;
    var allocator_object: AllocatorObject = undefined;
    allocator_object.init() catch
        return failStartup(app_title, "Could not init allocator");
    defer allocator_object.deinit();

    global_allocator = allocator_object.allocator();

    mainFunc();

    return 0;
}

fn failStartup(
    comptime app_title: []const u8,
    comptime message: []const u8,
) os.INT {
    _ = message_box.showComptime(
        app_title,
        message,
        .ok,
    ) catch {}; // we are already failing, ignore further errors
    return 0;
}
