const std = @import("std");

pub fn accept(template: anytype, Callbacks: type) void {
    const Template = @TypeOf(template);

    const cbk_fields = @typeInfo(Callbacks).@"struct".fields;
    for (cbk_fields) |cbk_field| {
        if (!@hasField(Template, cbk_field.name))
            @compileError("Unknown callback " ++ cbk_field.name);
    }
}

pub fn getOptional(
    callbacks_ptr: anytype,
    comptime field: []const u8,
) if (@hasField(@TypeOf(callbacks_ptr.*), field))
    @TypeOf(&@field(callbacks_ptr, field))
else
    *const void {
    return if (@hasField(@TypeOf(callbacks_ptr.*), field))
        &@field(callbacks_ptr, field)
    else
        &{};
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

pub fn call1(
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

// ------------------------------

fn ParsedSpec(Spec: type, comptime field: []const u8) type {
    // Spec is expected to be a struct type
    const info = @typeInfo(Spec).@"struct";

    // spec cannot contain any decls
    comptime std.debug.assert(info.decls.len == 0);

    if (info.fields.len == 0)
        return void;

    // spec can contain only one field at most
    comptime std.debug.assert(info.fields.len == 1);

    // if spec contains a field it must have the expected name
    return @FieldType(Spec, field);
}

// Returns a copy of the field contents or void
// Actually we'd like to return a pointer to the field contents
// to avoid an unnecessary copying of the field, but this
// causes problems due to Zig Issue #19483.
pub fn parseSpec(
    spec_ptr: anytype,
    comptime field: []const u8,
) ParsedSpec(@TypeOf(spec_ptr.*), field) {
    const Parsed = ParsedSpec(@TypeOf(spec_ptr.*), field);
    if (Parsed == void) return;

    return @field(spec_ptr, field);
}

pub fn call(
    parsed_callback_ptr: anytype,
    comptime method: []const u8,
    args: anytype,
    Result: type,
) Result {
    const ParsedCallback = @TypeOf(parsed_callback_ptr.*);
    const object_ptr = switch (@typeInfo(ParsedCallback)) {
        .pointer => parsed_callback_ptr.*,
        else => parsed_callback_ptr,
    };
    const Object = @TypeOf(object_ptr.*);

    // object is a tuple
    switch (@typeInfo(Object)) {
        .@"struct" => |info| if (info.is_tuple) {
            comptime std.debug.assert(object_ptr.len <= 2);
            return @call(
                .auto,
                object_ptr[0],
                if (object_ptr.len >= 1)
                    object_ptr[1] ++ args
                else
                    args,
            );
        },
        else => {},
    }

    // object is a container
    return @call(.auto, @field(Object, method), .{object_ptr} ++ args);
}
