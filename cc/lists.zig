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

// This test serves more like a list demo.
// More in-depth testing is done in lists/dbl/testing.zig
test "Simple list demo" {
    // A list with an i32 payload
    const L = List(i32, .{
        // Select list implementation
        .implementation = .{ .double_linked = .sentinel_terminated },

        // List nodes contain 'data' field with payload
        .layout = .simple_payload,

        // Track node ownership in debug builds using pointer to the list object.
        .ownership_tracking = .{
            .owned_items = .container_ptr,
            .free_items = .off,
        },
    });

    // Also could initialize to .{}, except for sentinel-terminated lists
    var l: L = undefined;

    // init() is available for all list types
    l.init();

    var n0: L.Node = undefined;
    n0.data = 0;
    l.insertLast(&n0);

    var n1: L.Node = undefined;
    l.insert(.after(null), &n1);
    n1.data = 1;

    {
        var node = l.first();
        while (node) |n| node = l.next(n);
        node = l.last();
        while (node) |n| node = l.prev(n);
    }
    l.remove(&n1);
}
