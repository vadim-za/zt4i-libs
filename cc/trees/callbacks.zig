const std = @import("std");

pub fn accept(template: anytype, Callbacks: type) void {
    const Template = @TypeOf(template);

    const cbk_fields = @typeInfo(Callbacks).@"struct".fields;
    for (cbk_fields) |cbk_field| {
        if (!@hasField(Template, cbk_field.name))
            @compileError("Unknown callback " ++ cbk_field.name);
    }
}

pub fn ResultOf(
    Callback: type,
    comptime method: []const u8,
) type {
    const Callable = cl: {
        switch (@typeInfo(Callback)) {
            .@"struct" => |info| if (info.is_tuple)
                break :cl info.fields[0].type,
            else => {},
        }
        break :cl @TypeOf(@field(Callback, method));
    };

    const Fn = switch (@typeInfo(Callable)) {
        .pointer => |p| p.child,
        else => Callable,
    };

    return @typeInfo(Fn).@"fn".return_type.?;
}

pub fn call(
    callback_ptr: anytype,
    comptime method: []const u8,
    args: anytype,
) ResultOf(@TypeOf(callback_ptr.*), method) {
    const Callback = @TypeOf(callback_ptr.*);

    // object is a tuple
    switch (@typeInfo(Callback)) {
        .@"struct" => |info| if (info.is_tuple) {
            comptime std.debug.assert(callback_ptr.len <= 2);
            return @call(
                .auto,
                callback_ptr[0],
                if (callback_ptr.len >= 1)
                    callback_ptr[1] ++ args
                else
                    args,
            );
        },
        else => {},
    }

    // object is a container
    return @call(.auto, @field(Callback, method), .{callback_ptr} ++ args);
}
