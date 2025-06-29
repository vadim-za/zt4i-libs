const std = @import("std");
const builtin = @import("builtin");
const zt4i = @import("zt4i");

const app_title = "zt4i-libs demo";

pub const wWinMain = zt4i.gui.wWinMain(
    app_title,
    appMain,
    null,
);

pub const panic = std.debug.FullPanic(panicFn);

// Display panic message in a message box before dumping
// it to stderr. Otherwise chances are the message won't
// even be seen unless running under debugger.
//
// This implementation only supports panicking from
// the main GUI thread. Panicking from other threads
// may lead to incorrect functionality.
fn panicFn(
    msg: []const u8,
    first_trace_addr: ?usize,
) noreturn {
    @branchHint(.cold);

    const Statics = struct {
        var panicking = false;
    };
    const already_panicking = Statics.panicking;
    Statics.panicking = true;

    if (!already_panicking) {
        const title = app_title ++ " - Panic";
        _ = zt4i.gui.showPanicMessageBox(title, msg, 2000);
    }

    return std.debug.defaultPanic(msg, first_trace_addr);
}

const Window = struct {
    core: zt4i.gui.Window = .{},
    dr: struct {
        red_brush: zt4i.gui.SolidBrush = .init(.initRgb(1, 0, 0)),
    } = .{},
    path: zt4i.gui.Path = .{},
    font: zt4i.gui.Font = .{},
    xy: ?zt4i.gui.Point = null,
    timer_flag: bool = false,
    timer: zt4i.gui.Timer(struct {
        window: *Window,
        pub fn init(window: *Window) @This() {
            return .{ .window = window };
        }
        pub fn onTimer(self: *@This()) void {
            self.window.timer_flag = !self.window.timer_flag;
            self.window.core.redraw(false);
        }
    }),

    const Results = zt4i.gui.Window.Responders(@This()).Results;

    pub fn init(self: *@This()) !void {
        self.* = .{
            .timer = .{ .payload = .init(self) },
        };
        errdefer self.deinit();

        self.core.addDeviceResource(&self.dr.red_brush);

        {
            var sink = try zt4i.gui.Path.begin(.closed, &.{ .x = 300, .y = 200 });
            sink.addLines(&[_]zt4i.gui.Point{
                .{ .x = 350, .y = 250 },
                .{ .x = 400, .y = 200 },
            });
            self.path = try sink.close();
        }

        self.font = try .init("Verdana", 15);
    }

    fn deinit(self: *@This()) void {
        self.core.removeAllDeviceResources(); // do this before core.deinit()
        self.core.deinit();
        self.path.deinit();
        self.font.deinit();
    }

    fn create(self: *@This(), width: f32, height: f32) zt4i.gui.Error!void {
        return zt4i.gui.Window.create(
            @This(),
            self,
            .default,
            .{
                .title = app_title,
                .width = width,
                .height = height,
            },
            .{ onCreate, .{self} },
        );
    }

    // This function is named as one of the responders, but does not
    // belong to them, it is passed manually to zt4i.gui.Window.create().
    // Generally it should be the symmetric part of onDestroy, but containing
    // the initializations which are deinitialized in onDestroy. onDestroy()
    // is not called if onCreate() fails.
    pub fn onCreate(self: *@This()) zt4i.gui.Error!void {
        try self.timer.setupWithWindow(&self.core, 1.0);
    }

    // onDestroy() is not called if window creation fails before
    // calling onCreate().
    pub fn onDestroy(self: *@This()) void {
        self.timer.releaseWithWindow(&self.core);
        zt4i.gui.stopMessageLoop();
    }

    pub fn onPaint(self: *@This(), dc: *zt4i.gui.DrawContext) void {
        dc.clear(&.initRgb(0, 0, 1));

        const red_brush = self.dr.red_brush.ref();

        dc.fillRectangle(
            &.{ .left = 100, .right = 200, .top = 100, .bottom = 150 },
            red_brush,
        );
        dc.drawLine(
            &.{ .x = 200, .y = 200 },
            &.{ .x = 300, .y = 300 },
            red_brush,
            2,
        );
        dc.drawRectangle(
            &.{ .left = 400, .top = 100, .right = 500, .bottom = 150 },
            red_brush,
            2,
        );
        //dc.fillPath(&self.path, red_brush);
        dc.drawPath(&self.path, red_brush, 2);

        if (self.timer_flag)
            dc.drawEllipse(
                &.{ .x = 450, .y = 200 },
                &.{ .x = 20, .y = 10 },
                red_brush,
                1,
            );

        dc.fillEllipse(
            &.{ .x = 500, .y = 200 },
            &.{ .x = 20, .y = 10 },
            red_brush,
        );

        if (self.xy) |xy| {
            var buf: [100]u8 = undefined;
            const text = std.fmt.bufPrint(
                &buf,
                "{d},{d}",
                .{ xy.x, xy.y },
            ) catch |err| switch (err) {
                error.NoSpaceLeft => &buf,
            };

            dc.drawText(
                &self.font,
                &.{ .left = 400, .top = 300, .right = 600, .bottom = 350 },
                text,
                self.dr.red_brush.ref(),
            ) catch |err| std.debug.assert(err != zt4i.gui.Error.Usage);
        }
    }

    pub fn onMouse(
        self: *@This(),
        event: *const zt4i.gui.mouse.Event,
    ) ?Results.OnMouse {
        switch (event.action.type) {
            .down => return .capture,
            .move => {
                self.xy = event.pos;
                self.core.redraw(false);
                return .processed;
            },
            .up => {
                _ = zt4i.gui.showMessageBox(
                    &self.core,
                    "Caption",
                    "Text",
                    .ok,
                ) catch {};
                return .processed;
            },
        }
    }

    pub fn onKey(
        self: *@This(),
        event: *const zt4i.gui.keys.Event,
    ) ?void {
        if (event.logical_action == .down and event.char != null) {
            var utf8buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(event.char.?, &utf8buf) catch {
                if (std.debug.runtime_safety)
                    @panic("Unicode conversion error in keyboard input");
            };

            const utf8str = utf8buf[0..len];
            _ = zt4i.gui.showMessageBox(
                &self.core,
                "Caption",
                utf8str,
                .ok,
            ) catch {};

            return {};
        }
        return null;
    }
};

fn appMain() void {
    var window: Window = undefined;
    window.init() catch {
        _ = zt4i.gui.showComptimeMessageBox(
            null,
            app_title,
            "Failed to initialize window",
            .ok,
        ) catch {};
        return;
    };
    defer window.deinit();
    window.create(800, 500) catch return;
    // _ = zt4i.gui.showMessageBox(
    //     &window.core,
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
    zt4i.gui.runMessageLoop();
}
