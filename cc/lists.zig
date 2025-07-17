const lib = @import("lib.zig");

pub const Implementation = @import("lists/impl.zig").Implementation;
pub const InsertionPos = @import("lists/insertion_pos.zig").InsertionPos;

pub fn List(
    T: type,
    impl: Implementation,
    layout: lib.Layout,
) type {
    return impl.namespace().List(T, layout);
}

// -----------------------------------------------------------------------

test "All" {
    const L = List(
        i32,
        .{ .double_linked = .null_terminated },
        .simple_payload,
    );
    var n: L.Node = undefined;
    var l: L = .{};
    l.insertLast(&n);
    @breakpoint();
}
