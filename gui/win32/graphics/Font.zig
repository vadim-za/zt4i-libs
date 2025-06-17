const com = @import("../com.zig");
const dwrite = @import("../dwrite.zig");
const directx = @import("../directx.zig");

dwrite_text_format: ?*dwrite.ITextFormat = null,

pub fn init(family: []const u8, size: f32) com.Error!@This() {
    const factory = directx.getDWriteFactory();

    const dwrite_text_format = try factory.createTextFormat(
        family,
        null,
        .NORMAL,
        .NORMAL,
        .NORMAL,
        size,
    );

    return .{
        .dwrite_text_format = dwrite_text_format,
    };
}

pub fn deinit(self: *@This()) void {
    if (self.dwrite_text_format) |format| {
        com.release(format);
        self.dwrite_text_format = null;
    }
}
