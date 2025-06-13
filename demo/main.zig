const z2 = @import("z2");

const app_title = "z2-libs demo";
pub const wWinMain = z2.paw.wWinMain(
    app_title,
    pawMain,
);

fn pawMain() void {
    _ = z2.paw.message_box.showComptime(
        "Caption",
        "Text",
        .ok,
    ) catch {};
}
