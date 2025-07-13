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
        _ = zt4i.gui.mbox.showPanic(title, msg, 2000);
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
    popup_menu: zt4i.gui.menus.Popup = undefined,
    menu_bar: zt4i.gui.menus.Bar = undefined,
    undo_menu: *zt4i.gui.menus.Contents = undefined,
    undo_command: *zt4i.gui.menus.Command = undefined,
    counter: usize = 0,

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

        {
            try self.menu_bar.create();
            errdefer self.menu_bar.destroy();

            const bar = self.menu_bar.contents();

            self.undo_menu = (try bar.addSubmenu(.last, "Undo")).contents();
            self.undo_command = try self.undo_menu.addCommand(.last, "Undo", 20);
        }

        {
            try self.popup_menu.create();
            errdefer self.popup_menu.destroy();

            const popup = self.popup_menu.contents();
            var command1 = try popup.addCommand(.first, "item 1", 0);
            const separator1 = try popup.addSeparator(.last);
            const command2 = try popup.addCommand(.after(separator1), "item 2", 2);
            const anchor1 = try popup.addAnchor(.before(command2));
            const command3 = try popup.addCommand(.after(anchor1), "item 3", 0);
            const command4 = try popup.addCommand(.after(command2), "item 4", 0);
            popup.deleteItem(command2);
            //_ = try popup.addCommand(.before(command4), "sub", 0);
            try popup.modifyCommand(command4, null, .{ .checked = true });
            try popup.modifyCommand(command3, "abc", null);
            command1 = try popup.addCommand(.replace(command1), "Test", 1);

            const submenu1 = try popup.addSubmenu(.before(command4), "Submenu");
            {
                const submenu = submenu1.contents();
                _ = try submenu.addCommand(.last, "subitem 1", 10);
            }
            try popup.modifySubmenu(submenu1, "Submenu mod", null);
        }
    }

    fn deinit(self: *@This()) void {
        self.core.removeAllDeviceResources(); // do this before core.deinit()
        self.core.deinit();
        self.path.deinit();
        self.font.deinit();
        self.popup_menu.destroy();
        self.menu_bar.destroy();
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
        try self.menu_bar.attachTo(&self.core);
        errdefer self.menu_bar.detachFrom(&self.core);

        // We don't really need to call update() here, as we're not modifying
        // the attached menu, but let's simply see if the code successfully
        // instantiates.
        self.menu_bar.update();

        try self.timer.setupWithinWindow(&self.core, 1.0);
    }

    // onDestroy() is not called if window creation fails before
    // or during calling onCreate().
    pub fn onDestroy(self: *@This()) void {
        self.timer.releaseWithinWindow(&self.core);
        self.menu_bar.detachFrom(&self.core);
        zt4i.gui.mloop.stop();
    }

    pub fn onMenuBarOpen(self: *@This()) void {
        self.counter += 1;
        var buf: [100]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Undo {}", .{self.counter}) catch unreachable;
        self.undo_menu.modifyCommand(self.undo_command, text, null) catch {};
    }

    pub fn onCommand(self: *@This(), id: usize) ?void {
        if (id == 20) {
            var buf: [100]u8 = undefined;
            const text = std.fmt.bufPrint(&buf, "Undo {}", .{self.counter}) catch unreachable;
            _ = zt4i.gui.mbox.show(&self.core, "Command", text, .ok) catch {};
            return {};
        }
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

        {
            const old_origin = dc.moveOriginBy(&.{ .x = 400, .y = 200 });
            defer _ = dc.setOrigin(old_origin);
            if (self.timer_flag)
                dc.drawEllipse(
                    &.{ .x = 50, .y = 0 },
                    &.{ .x = 20, .y = 10 },
                    red_brush,
                    1,
                );
        }

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
            .down => switch (event.action.button.?) {
                .left => return .capture,
                .right => {
                    if (self.popup_menu.run(
                        &self.core,
                    ) catch null) |cmd| switch (cmd) {
                        1 => _ = zt4i.gui.mbox.show(
                            &self.core,
                            "Caption",
                            "Text",
                            .ok,
                        ) catch {},
                        else => {},
                    };
                    return .dont_capture;
                },
                else => return .dont_capture,
            },
            .move => {
                self.xy = event.pos;
                self.core.redraw(false);
                return .processed;
            },
            .up => return .processed,
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
            _ = zt4i.gui.mbox.show(
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
        _ = zt4i.gui.mbox.showComptime(
            null,
            app_title,
            "Failed to initialize window",
            .ok,
        ) catch {};
        return;
    };
    defer window.deinit();
    window.create(800, 500) catch return;
    // _ = zt4i.gui.mbox.show(
    //     &window.core,
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
    zt4i.gui.mloop.run();
}
