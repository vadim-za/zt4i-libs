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
        gray_brush: z2.paw.SolidBrush = .init(.initGray(0.5)),
    } = .{},

    pub fn init(self: *@This()) void {
        self.* = .{};

        const dr = self.core.deviceResources();
        dr.addResource(&self.dr.gray_brush);
    }

    fn deinit(self: *@This()) void {
        const dr = self.core.deviceResources();
        dr.removeAllResources();

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

    pub fn onPaint(_: *@This(), dc: *z2.paw.DrawContext) void {
        dc.clear(.initRgb(0, 0, 1));
    }
};

fn pawMain() void {
    var window: Window = undefined;
    window.init();
    defer window.deinit();
    window.create(800, 500) catch return;
    z2.paw.runMessageLoop();
    // _ = z2.paw.showMessageBox(
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
}
