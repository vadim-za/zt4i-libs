const std = @import("std");
const os = std.os.windows;

var hThisInstance: ?os.HINSTANCE = null;

pub fn thisInstance() ?os.HINSTANCE {
    return hThisInstance;
}

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
    _ = app_title; // autofix
    return struct {
        fn wWinMainSpecialization(
            hInst: ?os.HINSTANCE,
            _: ?os.HINSTANCE,
            _: ?os.LPCWSTR,
            _: os.INT,
        ) os.INT {
            hThisInstance = hInst;

            mainFunc();

            return 0;
        }
    }.wWinMainSpecialization;
}
