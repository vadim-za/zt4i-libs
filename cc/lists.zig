const std = @import("std");
const lib = @import("lib.zig");
const impl = @import("lists/impl.zig");

pub const Implementation = impl.Implementation;

pub const Config = struct {
    implementation: Implementation,
    hook_field: []const u8,
    ownership_tracking: lib.OwnershipTracking,
};

pub fn List(Node: type, cfg: Config) type {
    return cfg.implementation.namespace().List(
        Node,
        cfg.hook_field,
        cfg.ownership_tracking,
    );
}

pub fn SimpleList(
    Payload: type,
    implementation: Implementation,
    ownership_tracking: lib.OwnershipTracking,
) type {
    const Decls = struct {
        const Node = struct {
            data: Payload,
            hook: List_.Hook = .{},
        };

        const cfg = Config{
            .implementation = implementation,
            .hook_field = "hook",
            .ownership_tracking = ownership_tracking,
        };

        const List_ = List(Node, cfg);
    };

    return Decls.List_;
}

comptime {
    std.testing.refAllDecls(impl);
}

// -----------------------------------------------------------------------

// This test serves more like a minimal list demo.
// More in-depth testing is done in lists/dbl/testing.zig
// and lists/sgl/testing.zig
test "Simple list demo" {
    // A list with an i32 payload
    const L = SimpleList(
        i32,
        .{ .double_linked = .sentinel_terminated },
        .{
            // Track node ownership in debug builds using pointers to the list object.
            // Ownership tracking prevents inadvertent incorrect pairing of a node
            // with a list which doesn't own it (e.g. it list iteration or node removal).
            .owned_items = .container_ptr,

            // Track free items status, so that one cannot inadvertently insert
            // an already inserted item into anothe rlist.
            .free_items = .on,
        },
    );

    // Also could initialize to .{}, except for sentinel-terminated lists
    var l: L = undefined;

    // init() is available for all list types
    l.init();
    defer l.deinit();

    var n0: L.Node = .{ .data = undefined };
    n0.data = 0;
    l.insertFirst(&n0);

    var n1: L.Node = .{ .data = 1 };
    l.insert(.after(null), &n1);

    {
        var node = l.first();
        while (node) |n| node = l.next(n);
        // node = l.last();
        // while (node) |n| node = l.prev(n);
    }
    //l.removeFirst();
    l.remove(&n1);
    l.removeAll();
}
