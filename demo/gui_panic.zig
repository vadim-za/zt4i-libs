const std = @import("std");
const zt4i = @import("zt4i");
pub const main = @import("main.zig");

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
        const title = main.app_title ++ " - Panic";
        _ = zt4i.gui.mbox.showPanic(title, msg, 2000);
    }

    return std.debug.defaultPanic(msg, first_trace_addr);
}
