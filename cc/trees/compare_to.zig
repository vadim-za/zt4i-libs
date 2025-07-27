const std = @import("std");

pub const CompareTo = union(enum) {
    // Don't access fields directly, use methods to construct CompareTo values
    method_: []const u8,
    Function: type,

    /// Use std.math.order() for comparison. For single-item pointers
    /// use std.math.order() on the implied addresses.
    /// Cannot be applied to entire nodes (since structs cannot be compared
    /// with std.math.order()), which means it is more useful as the second
    /// argument to useField().
    pub const default = function(defaultCompareTo);

    pub fn method(name: []const u8) @This() {
        return .{ .method_ = name };
    }

    pub fn function(f: anytype) @This() {
        return .{ .Function = struct {
            const compareTo = f;
        } };
    }

    pub fn useField(
        field_name: []const u8,
        comptime compare_to: CompareTo, // comparison for the field
    ) @This() {
        return .{
            .Function = struct {
                fn compareTo(
                    reference_value_ptr: anytype,
                    comparable_value_ptr: anytype,
                ) std.math.Order {
                    const field_ptr = &@field(
                        reference_value_ptr,
                        field_name,
                    );

                    // If comparing to another node
                    if (@TypeOf(comparable_value_ptr.*) ==
                        @TypeOf(reference_value_ptr.*))
                    {
                        const comparable_field_ptr = &@field(
                            comparable_value_ptr,
                            field_name,
                        );
                        return compare_to.call(
                            field_ptr,
                            comparable_field_ptr,
                        );
                    }

                    return compare_to.call(
                        field_ptr,
                        comparable_value_ptr,
                    );
                }
            },
        };
    }

    pub fn call(
        comptime self: @This(),
        reference_value_ptr: anytype,
        comparable_value_ptr: anytype, // ptr to a value which can be compared to
    ) std.math.Order {
        const callable = switch (self) {
            .method_ => |method_name| @field(
                @TypeOf(reference_value_ptr.*),
                method_name,
            ),
            .Function => |F| F.compareTo,
        };

        return @call(.auto, callable, .{
            reference_value_ptr,
            comparable_value_ptr,
        });
    }
};

fn comparablePointer(T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.size == .one,
        else => false,
    };
}

fn defaultCompareTo(
    reference_value_ptr: anytype,
    comparable_value_ptr: anytype,
) std.math.Order {
    if (comptime comparablePointer(@TypeOf(reference_value_ptr.*)) and
        comparablePointer(@TypeOf(comparable_value_ptr.*)))
        return std.math.order(
            @intFromPtr(reference_value_ptr.*),
            @intFromPtr(comparable_value_ptr.*),
        );

    return std.math.order(reference_value_ptr.*, comparable_value_ptr.*);
}
