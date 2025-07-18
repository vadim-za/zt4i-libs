const std = @import("std");
const lib = @import("lib.zig");
const impl = @import("lists/impl.zig");

pub const Implementation = impl.Implementation;

pub const Config = struct {
    implementation: Implementation,
    layout: lib.Layout,
    ownership_tracking: lib.OwnershipTracking,
};

pub fn List(T: type, cfg: Config) type {
    return cfg.implementation.namespace().List(
        T,
        cfg.layout,
        cfg.ownership_tracking,
    );
}

comptime {
    std.testing.refAllDecls(impl);
}

// -----------------------------------------------------------------------

test "All" {
    const L = List(i32, .{
        .implementation = .{ .double_linked = .sentinel_terminated },
        .layout = .simple_payload,
        .ownership_tracking = .container_ptr,
    });
    var n0: L.Node = undefined;
    //var l: L = .{};
    var l: L = undefined;
    l.init();
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
}
