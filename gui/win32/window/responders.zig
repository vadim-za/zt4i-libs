const std = @import("std");
const Window = @import("../Window.zig");
const graphics = @import("../graphics.zig");
const gui = @import("../../gui.zig");

pub fn Responders(Impl: type) type {
    const ImplDefaults = Defaults(Impl);

    return struct {
        getCore: *const fn (impl: *Impl) *Window,
        onClose: *const fn (impl: *Impl) bool = override("onClose"),
        onDestroy: *const fn (impl: *Impl) void = override("onDestroy"),
        onPaint: *const fn (
            impl: *Impl,
            dc: *graphics.DrawContext,
        ) void = override("onPaint"),
        onMouse: *const fn (
            impl: *Impl,
            event: *const gui.mouse.Event,
        ) bool = override("onMouse"),
        onKey: *const fn (
            impl: *Impl,
            event: *const gui.keys.Event,
        ) bool = override("onKey"),

        pub const default = @This(){
            .getCore = if (@hasDecl(Impl, "getCore"))
                Impl.getCore
            else
                defaultGetCore,
        };

        fn defaultGetCore(impl: *Impl) *Window {
            return &impl.core;
        }

        fn override(comptime method: []const u8) *const MethodType(method) {
            return if (@hasDecl(Impl, method))
                @field(Impl, method)
            else
                @field(ImplDefaults, method);
        }

        fn MethodType(comptime method: []const u8) type {
            return @TypeOf(
                @field(ImplDefaults, method),
            );
        }
    };
}

fn Defaults(Impl: type) type {
    return struct {
        fn onClose(impl: *Impl) bool {
            _ = impl;
            return true;
        }
        fn onDestroy(impl: *Impl) void {
            _ = impl;
        }
        fn onPaint(impl: *Impl, dc: *graphics.DrawContext) void {
            _ = impl;
            _ = dc;
        }
        fn onMouse(impl: *Impl, event: *const gui.mouse.Event) bool {
            _ = impl;
            _ = event;
            return false;
        }
        fn onKey(impl: *Impl, event: *const gui.keys.Event) bool {
            _ = impl;
            _ = event;
            return false;
        }
    };
}

test "Defaults applied" {
    const Impl = struct {
        core: Window,
    };
    const r: Responders(Impl) = .default;

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.core, r.getCore(&impl));
    try std.testing.expectEqual(true, r.onClose(&impl));
}

test "getCore auto-overridden" {
    const Impl = struct {
        wnd: Window,
        fn getCore(self: *@This()) *Window {
            return &self.wnd;
        }
    };
    const r: Responders(Impl) = .default;

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.wnd, r.getCore(&impl));
    try std.testing.expectEqual(true, r.onClose(&impl));
}

test "onClose auto-overridden" {
    const Impl = struct {
        core: Window,
        fn onClose(self: *@This()) bool {
            _ = self;
            return false;
        }
    };
    const r: Responders(Impl) = .default;

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.core, r.getCore(&impl));
    try std.testing.expectEqual(false, r.onClose(&impl));
}

test "Defaults explicitly overridden" {
    const Impl = struct {
        wnd: Window,
    };
    const Methods = struct {
        fn getWindow(impl: *Impl) *Window {
            return &impl.wnd;
        }
        fn onClose(impl: *Impl) bool {
            _ = impl;
            return false;
        }
    };
    const r: Responders(Impl) = .{
        .getCore = Methods.getWindow,
        .onClose = Methods.onClose,
    };

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.wnd, r.getCore(&impl));
    try std.testing.expectEqual(false, r.onClose(&impl));
}
