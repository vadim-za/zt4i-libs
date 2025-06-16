const z2 = @import("z2");

const app_title = "z2-libs demo";

pub const wWinMain = z2.paw.wWinMain(
    app_title,
    pawMain,
    null,
);

const Window = struct {
    core: z2.paw.Window = .{},
    dr: struct {
        red_brush: z2.paw.SolidBrush = .init(.initRgb(1, 0, 0)),
    } = .{},

    pub fn init(self: *@This()) void {
        self.* = .{};

        self.core.addDeviceResource(&self.dr.red_brush);
    }

    fn deinit(self: *@This()) void {
        self.core.removeAllDeviceResources();

        self.core.deinit();
    }

    fn create(self: *@This(), width: f32, height: f32) z2.paw.Error!void {
        try z2.paw.Window.create(
            @This(),
            self,
            app_title,
            .default,
            width,
            height,
        );
    }

    pub fn onDestroy(_: *@This()) void {
        z2.paw.stopMessageLoop();
    }

    pub fn onPaint(self: *@This(), dc: *z2.paw.DrawContext) void {
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
    }
};

fn pawMain() void {
    var window: Window = undefined;
    window.init();
    defer window.deinit();
    window.create(800, 500) catch return;
    // _ = z2.paw.showMessageBox(
    //     &window.core,
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
    z2.paw.runMessageLoop();
}
