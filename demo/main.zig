const zz = @import("zz");

const app_title = "zz-libs demo";

pub const wWinMain = zz.paw.wWinMain(
    app_title,
    pawMain,
    null,
);

const Window = struct {
    core: zz.paw.Window = .{},
    dr: struct {
        red_brush: zz.paw.SolidBrush = .init(.initRgb(1, 0, 0)),
    } = .{},
    path: zz.paw.Path = .{},

    pub fn init(self: *@This()) !void {
        self.* = .{};

        self.core.addDeviceResource(&self.dr.red_brush);

        {
            var sink = try zz.paw.Path.begin(.closed, &.{ .x = 300, .y = 200 });
            sink.addLines(&[_]zz.paw.Point{
                .{ .x = 350, .y = 250 },
                .{ .x = 400, .y = 200 },
            });
            self.path = try sink.close();
        }
    }

    fn deinit(self: *@This()) void {
        self.core.removeAllDeviceResources();

        self.core.deinit();
        self.path.deinit();
    }

    fn create(self: *@This(), width: f32, height: f32) zz.paw.Error!void {
        try zz.paw.Window.create(
            @This(),
            self,
            app_title,
            .default,
            width,
            height,
        );
    }

    pub fn onDestroy(_: *@This()) void {
        zz.paw.stopMessageLoop();
    }

    pub fn onPaint(self: *@This(), dc: *zz.paw.DrawContext) void {
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

fn pawMain() void {
    var window: Window = undefined;
    window.init() catch {
        _ = zz.paw.showComptimeMessageBox(
            null,
            app_title,
            "Failed to initialize window",
            .ok,
        ) catch {};
        return;
    };
    defer window.deinit();
    window.create(800, 500) catch return;
    // _ = zz.paw.showMessageBox(
    //     &window.core,
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
    zz.paw.runMessageLoop();
}
