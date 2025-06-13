const z2 = @import("z2");

const app_title = "z2-libs demo";

pub const wWinMain = z2.paw.wWinMain(
    app_title,
    pawMain,
    null,
);

const Window = struct {
    core: z2.paw.Window = .{},

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
};

fn pawMain() void {
    var window: Window = .{};
    window.create(800, 500) catch return;
    z2.paw.runMessageLoop();
    // _ = z2.paw.showMessageBox(
    //     "Caption",
    //     "Text",
    //     .ok,
    // ) catch {};
}
