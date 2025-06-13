const z2 = @import("z2");

const app_title = "z2-libs demo";

pub const wWinMain = z2.paw.wWinMain(
    app_title,
    pawMain,
    null,
);

fn pawMain() void {
    _ = z2.paw.showMessageBox(
        "Caption",
        "Text",
        .ok,
    ) catch {};
}
