const std = @import("std");
const Window = @import("../Window.zig");
const graphics = @import("../graphics.zig");
const gui = @import("../../gui.zig");

// Results which do not depend on Impl
pub const CommonResults = struct {
    pub const OnClose = enum { destroy_window, dont_destroy_window };
    pub const OnMouse = enum { capture, dont_capture, processed };
};

pub fn Responders(Impl: type) type {
    const ResultsForImpl = CommonResults;
    const ImplDefaults = Defaults(Impl, ResultsForImpl);

    return struct {
        pub const Results = ResultsForImpl;

        getCore: *const fn (impl: *Impl) *Window,

        onClose: *const fn (impl: *Impl) Results.OnClose = override("onClose"),
        onDestroy: *const fn (impl: *Impl) void = override("onDestroy"),
        onPaint: *const fn (
            impl: *Impl,
            dc: *graphics.DrawContext,
        ) void = override("onPaint"),
        onMenuBarOpen: *const fn (imp: *Impl) void = override("onMenuBarOpen"),
        onMouse: *const fn (
            impl: *Impl,
            event: *const gui.mouse.Event,
        ) ?Results.OnMouse = override("onMouse"),
        onKey: *const fn (
            impl: *Impl,
            event: *const gui.keys.Event,
        ) ?void = override("onKey"),

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

fn Defaults(Impl: type, Results: type) type {
    return struct {
        fn onClose(impl: *Impl) Results.OnClose {
            _ = impl;
            return .destroy_window;
        }

        fn onDestroy(impl: *Impl) void {
            _ = impl;
        }

        fn onPaint(impl: *Impl, dc: *graphics.DrawContext) void {
            _ = impl;
            _ = dc;
        }

        fn onMenuBarOpen(impl: *Impl) void {
            _ = impl;
        }

        fn onMouse(
            impl: *Impl,
            event: *const gui.mouse.Event,
        ) ?Results.OnMouse {
            _ = impl;
            _ = event;
            return null;
        }

        fn onKey(impl: *Impl, event: *const gui.keys.Event) ?void {
            _ = impl;
            _ = event;
            return null;
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
    try std.testing.expectEqual(.destroy_window, r.onClose(&impl));
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
    try std.testing.expectEqual(.destroy_window, r.onClose(&impl));
}

test "onClose auto-overridden" {
    const Impl = struct {
        core: Window,
        fn onClose(self: *@This()) Responders(@This()).Results.OnClose {
            _ = self;
            return .dont_destroy_window;
        }
    };
    const r: Responders(Impl) = .default;

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.core, r.getCore(&impl));
    try std.testing.expectEqual(.dont_destroy_window, r.onClose(&impl));
}

test "Defaults explicitly overridden" {
    const Impl = struct {
        wnd: Window,
    };
    const Resps = Responders(Impl);
    const Methods = struct {
        fn getWindow(impl: *Impl) *Window {
            return &impl.wnd;
        }
        fn onClose(impl: *Impl) Resps.Results.OnClose {
            _ = impl;
            return .dont_destroy_window;
        }
    };
    const r: Resps = .{
        .getCore = Methods.getWindow,
        .onClose = Methods.onClose,
    };

    var impl: Impl = undefined;
    try std.testing.expectEqual(&impl.wnd, r.getCore(&impl));
    try std.testing.expectEqual(.dont_destroy_window, r.onClose(&impl));
}
