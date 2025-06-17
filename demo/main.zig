const zz = @import("zz");

const app_title = "zz-libs demo";

pub const wWinMain = zz.gui.wWinMain(
    app_title,
    zzMain,
    null,
);

const Window = struct {
    core: zz.gui.Window = .{},
    dr: struct {
        red_brush: zz.gui.SolidBrush = .init(.initRgb(1, 0, 0)),
    } = .{},
    path: zz.gui.Path = .{},
    font: zz.gui.Font = .{},

    pub fn init(self: *@This()) !void {
        self.* = .{};
        errdefer self.deinit();

        self.core.addDeviceResource(&self.dr.red_brush);

        {
            var sink = try zz.gui.Path.begin(.closed, &.{ .x = 300, .y = 200 });
            sink.addLines(&[_]zz.gui.Point{
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

    fn create(self: *@This(), width: f32, height: f32) zz.gui.Error!void {
        try zz.gui.Window.create(
            @This(),
            self,
            app_title,
            .default,
            width,
            height,
        );
    }

    pub fn onDestroy(_: *@This()) void {
        zz.gui.stopMessageLoop();
    }

    pub fn onPaint(self: *@This(), dc: *zz.gui.DrawContext) void {
        dc.clear(.initRgb(0, 0, 1));
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
    }
};

fn zzMain() void {
    var window: Window = undefined;
    window.init() catch {
        _ = zz.gui.showComptimeMessageBox(
            null,
            app_title,
            "Failed to initialize window",
            .ok,
        ) catch {};
        return;
    };
    defer window.deinit();
    window.create(800, 500) catch return;
    // _ = zz.gui.showMessageBox(
    //     &window.core,
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
    zz.gui.runMessageLoop();
}
