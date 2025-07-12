const std = @import("std");
const builtin = @import("builtin");

const gui = @import("../../gui.zig");
const Window = @import("../Window.zig");
const class = @import("class.zig");
const Responders = @import("responders.zig").Responders;
const d2d1 = @import("../d2d1.zig");
const graphics = @import("../graphics.zig");
const mouse_util = @import("mouse_util.zig");
const keys_util = @import("keys_util.zig");
const debug = @import("../debug.zig");

const os = std.os.windows;

// ----------------------------------------------------------------

const WM_DESTROY: os.UINT = 0x2;
pub const WM_PAINT: os.UINT = 0xF;
pub const WM_CLOSE: os.UINT = 0x10;
const WM_DISPLAYCHANGE: os.UINT = 0x7E;
const WM_KEYDOWN: os.UINT = 0x100;
const WM_COMMAND: os.UINT = 0x111;

pub extern "user32" fn BeginPaint(
    hWnd: os.HWND,
    lpPaint: *PAINTSTRUCT,
) callconv(.winapi) ?os.HDC;
pub extern "user32" fn EndPaint(
    hWnd: os.HWND,
    lpPaint: *const PAINTSTRUCT,
) callconv(.winapi) os.BOOL;

pub const PAINTSTRUCT = extern struct {
    hdc: os.HDC,
    fErase: os.BOOL,
    rcPaint: os.RECT,
    fRestore: os.BOOL,
    fIncUpdate: os.BOOL,
    rgbReserved: [32]os.BYTE,
};

// ----------------------------------------------------------------

pub const ReceivedMessageCore = struct {
    window: *Window,
    uMsg: os.UINT,
    wParam: os.WPARAM,
    lParam: os.LPARAM,
};

pub fn ReceivedMessage(
    Impl: type,
    comptime resps: Responders(Impl),
) type {
    return struct {
        impl: *Impl,
        core: ReceivedMessageCore,

        pub const Result = union(enum) {
            return_value: os.LRESULT,
            call_default: void,

            const zero = @This(){ .return_value = 0 };
        };

        pub fn handle(
            self: *const @This(),
        ) Result {
            if (self.handleMouse()) |result|
                return result;

            if (self.handleKey()) |result|
                return result;

            return switch (self.core.uMsg) {
                WM_DESTROY => self.onDestroy(),
                WM_PAINT, WM_DISPLAYCHANGE => self.onPaint(),
                WM_CLOSE => self.onClose(),
                WM_COMMAND => self.onCommand(),
                else => .call_default,
            };
        }

        fn onDestroy(self: *const @This()) Result {
            const window = self.core.window;

            resps.onDestroy(self.impl);

            // Menu, if any, must have been discarded in onDestroy responder
            debug.expect(window.menu_bar == null);

            class.subclass(window.hWnd.?, null, null);
            window.device_resources.releaseResources();
            window.hWnd = null;
            window.dpr = null;
            return .zero;
        }

        fn onPaint(self: *const @This()) Result {
            const window = self.core.window;

            var ps: PAINTSTRUCT = undefined;
            _ = BeginPaint(window.hWnd.?, &ps);
            defer _ = EndPaint(window.hWnd.?, &ps);

            const hwnd_target =
                window.device_resources.provideResourcesFor(
                    window.hWnd.?,
                ) catch {
                    // having no render target or resources is fatal
                    if (builtin.mode == .Debug)
                        @panic("Failed to create window device resources");
                    return .zero;
                };

            if (hwnd_target.checkWindowState().OCCLUDED)
                return .zero;

            const target = hwnd_target.as(d2d1.IRenderTarget);
            target.beginDraw();
            defer target.endDraw() catch |err| switch (err) {
                error.RecreateTarget => window
                    .device_resources.releaseResources(),
                else => {},
            };

            var dc = graphics.DrawContext{
                .target = target,
                .origin = .zero,
            };
            resps.onPaint(self.impl, &dc);
            return .zero;
        }

        fn onClose(self: *const @This()) Result {
            const window = self.core.window;
            switch (resps.onClose(self.impl)) {
                .destroy_window => window.destroy(),
                .dont_destroy_window => {},
            }
            return .zero;
        }

        fn onCommand(self: *const @This()) Result {
            _ = self;
            return .zero;
        }

        fn handleMouse(self: *const @This()) ?Result {
            const mouse_event = mouse_util.eventFromMsg(&self.core) orelse
                return null;

            mouse_util.preprocessEvent(self.core.window, &mouse_event);

            if (resps.onMouse(self.impl, &mouse_event)) |result| {
                mouse_util.handleEventResult(
                    self.core.window,
                    &mouse_event,
                    result,
                );
                return .zero;
            }

            return null;
        }

        fn handleKey(self: *const @This()) ?Result {
            const event, const is_char =
                keys_util.eventFromMsg(&self.core) orelse return null;

            if (is_char)
                return self.handleChar(
                    &event,
                    @as(u16, @truncate(self.core.wParam)),
                )
            else {
                return if (resps.onKey(self.impl, &event)) |_|
                    .zero
                else
                    null;
            }
        }

        fn handleChar(
            self: *const @This(),
            event: *const gui.keys.Event,
            wtf16char: u16,
        ) ?Result {
            if (comptime builtin.cpu.arch.endian() != .little)
                @compileError("Only little endian archs supported by Win32 backend");

            // TODO: Handle surrogate pairs
            if (std.unicode.utf16IsHighSurrogate(wtf16char) or
                std.unicode.utf16IsLowSurrogate(wtf16char))
                return null;

            var char_event = event.*;
            char_event.char = wtf16char;
            return if (resps.onKey(self.impl, &char_event)) |_|
                .zero
            else
                null;
        }
    };
}
