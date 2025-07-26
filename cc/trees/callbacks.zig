const std = @import("std");

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
    const Field = @FieldType(Spec, field);

    return switch (@typeInfo(Field)) {
        .pointer => Field,
        else => *const Field,
    };
}

// Returns a pointer to the field contents or void
pub fn parseSpec(
    spec_ptr: anytype,
    comptime field: []const u8,
) ParsedSpec(@TypeOf(spec_ptr.*), field) {
    const Parsed = ParsedSpec(@TypeOf(spec_ptr.*), field);
    if (Parsed == void) return;

    const Field = @FieldType(@TypeOf(spec_ptr.*), field);
    return switch (@typeInfo(Field)) {
        .pointer => @field(spec_ptr, field),
        else => &@field(spec_ptr, field), // Fails due to Zig Issue #19483
    };
}

pub fn call(
    object_ptr: anytype,
    comptime method: []const u8,
    args: anytype,
    Result: type,
) Result {
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
