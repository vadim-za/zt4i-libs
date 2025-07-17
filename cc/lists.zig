const lib = @import("lib.zig");

pub const Implementation = @import("lists/impl.zig").Implementation;

pub fn List(
    T: type,
    impl: Implementation,
    layout: lib.Layout,
) type {
    return impl.namespace().List(T, layout);
}

// -----------------------------------------------------------------------

test "All" {
    const T = List(
        i32,
        .{ .double_linked = .null_terminated },
        .simple_payload,
    );
    _ = T;
    @breakpoint();
}
