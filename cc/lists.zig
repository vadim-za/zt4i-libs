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
    const L = List(
        i32,
        .{ .double_linked = .null_terminated },
        .simple_payload,
    );
    var n0: L.Node = undefined;
    var l: L = .{};
    l.insertLast(&n0);
    var n1: L.Node = undefined;
    l.insert(.after(null), &n1);
    {
        var node = l.first();
        while (node) |n| node = l.next(n);
        node = l.last();
        while (node) |n| node = l.prev(n);
    }
    l.remove(&n1);
    @breakpoint();
}
