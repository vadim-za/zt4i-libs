const std = @import("std");
const lib = @import("../../lib.zig");

const Payload = i32;

const tested_configs = configs: {
    var configs: []const lib.lists.Config = &.{};

    for ([_]std.meta.Tag(lib.lists.Implementation.DoubleLinked){
        .null_terminated,
        .sentinel_terminated,
        .single_ptr,
    }) |impl| {
        for ([_]lib.OwnershipTracking{
            .container_ptr,
            .{ .custom = i32 },
            .off,
        }) |tracking| {
            configs = configs ++ [1]lib.lists.Config{.{
                .implementation = .{ .double_linked = impl },
                .layout = .simple_payload,
                .ownership_tracking = tracking,
            }};
        }
    }

    break :configs configs;
};

test "insertLast" {
    inline for (tested_configs) |config| {
        const List = lib.lists.List(Payload, config);
        const impl = comptime config.implementation.double_linked;
        var list: List = if (impl == .sentinel_terminated)
            undefined
        else
            .{};
        list.init(); // redundant if .{} initialization is done above
        if (comptime config.ownership_tracking == .custom)
            list.setOwnershipToken(1);

        const Node = List.Node;
        var nodes: [2]Node = undefined;

        list.insert(.last, &nodes[0]); // same as list.insertLast(&nodes[0])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));
        try std.testing.expectEqual(null, list.prev(&nodes[0]));

        list.insertLast(&nodes[1]); // same as list.insert(.last, &nodes[1])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(null, list.prev(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.next(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[1]));
        try std.testing.expectEqual(&nodes[0], list.prev(&nodes[1]));

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
    }

    @breakpoint();
}
