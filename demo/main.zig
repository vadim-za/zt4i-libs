const std = @import("std");
const zt4i = @import("zt4i");

const app_title = "zt4i-libs demo";

pub const wWinMain = zt4i.gui.wWinMain(
    app_title,
    appMain,
    null,
);

const Window = struct {
    core: zt4i.gui.Window = .{},
    dr: struct {
        red_brush: zt4i.gui.SolidBrush = .init(.initRgb(1, 0, 0)),
    } = .{},
    path: zt4i.gui.Path = .{},
    font: zt4i.gui.Font = .{},
    xy: ?zt4i.gui.Point = null,

    const Results = zt4i.gui.Window.Responders(@This()).Results;

    pub fn init(self: *@This()) !void {
        self.* = .{};
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
        try zt4i.gui.Window.create(
            @This(),
            self,
            app_title,
            .default,
            width,
            height,
        );
    }

    pub fn onDestroy(_: *@This()) void {
        zt4i.gui.stopMessageLoop();
    }

    pub fn onPaint(self: *@This(), dc: *zt4i.gui.DrawContext) void {
        dc.clear(&.initRgb(0, 0, 1));
        dc.fillRectangle(
            &.{ .left = 100, .right = 200, .top = 100, .bottom = 150 },
            self.dr.red_brush.ref(),
        );
        dc.drawLine(
            &.{ .x = 200, .y = 200 },
            &.{ .x = 300, .y = 300 },
            self.dr.red_brush.ref(),
            2,
        );
        dc.drawRectangle(
            &.{ .left = 400, .top = 100, .right = 500, .bottom = 150 },
            self.dr.red_brush.ref(),
            2,
        );
        //dc.fillPath(&self.path, self.dr.red_brush.ref());
        dc.drawPath(&self.path, self.dr.red_brush.ref(), 2);

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
                utf8str, //"Key",
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
