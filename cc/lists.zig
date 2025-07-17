pub const ApiPreferences = @import("ApiPreferences.zig");
pub const Implementation = @import("lists/impl.zig").Implementation;

pub fn List(
    impl: Implementation,
    T: type,
    Layout: type,
    api_preferences: ApiPreferences,
) type {
    return impl.namespace().List(T, Layout, api_preferences);
}

// -----------------------------------------------------------------------

test "All" {
    const T = List(
        .{ .double_linked = .null_terminated },
        i32,
        void,
        .{
            .init = .value,
            .init_layout_arg = .auto,
        },
    );
    _ = T;
    @breakpoint();
}
