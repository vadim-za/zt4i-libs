const std = @import("std");
const zt4i = @import("zt4i");
const Window = @import("Window.zig");

pub const app_title = "zt4i-libs demo";

pub const wWinMain = zt4i.gui.wWinMain(
    app_title,
    appMain,
    1,
    null,
);

pub const panic = @import("gui_panic.zig").panic;

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
    zt4i.gui.mloop.run();
}
