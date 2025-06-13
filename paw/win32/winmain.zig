const std = @import("std");
const os = std.os.windows;

const WWinMain = fn (
    hInst: ?os.HINSTANCE,
    _: ?os.HINSTANCE,
    _: ?os.LPCWSTR,
    _: os.INT,
) os.INT;

pub fn wWinMain(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
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

pub fn wWinMainImpl(
    comptime app_title: []const u8,
    comptime mainFunc: fn () void,
    hInst: ?os.HINSTANCE,
) os.INT {
    _ = app_title; // autofix

    this_instance = hInst;

    mainFunc();

    return 0;
}
