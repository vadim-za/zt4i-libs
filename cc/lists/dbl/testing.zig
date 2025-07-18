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

fn verifyConsistency(List: type, list: *List) !void {
    var node = list.first();
    while (node) |n| : (node = list.next(n)) {
        if (n == list.first())
            try std.testing.expectEqual(null, list.prev(n))
        else
            try std.testing.expectEqual(n, list.next(list.prev(n).?));

        if (n == list.last())
            try std.testing.expectEqual(null, list.next(n))
        else
            try std.testing.expectEqual(n, list.prev(list.next(n).?));
    }
}

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

        try verifyConsistency(List, &list);

        const Node = List.Node;
        var nodes: [2]Node = undefined;

        list.insert(.last, &nodes[0]); // same as list.insertLast(&nodes[0])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));
        try std.testing.expectEqual(null, list.prev(&nodes[0]));

        try verifyConsistency(List, &list);

        list.insertLast(&nodes[1]); // same as list.insert(.last, &nodes[1])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(null, list.prev(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.next(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[1]));
        try std.testing.expectEqual(&nodes[0], list.prev(&nodes[1]));

        try verifyConsistency(List, &list);

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
    }
}

test "insertFirst" {
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

        try verifyConsistency(List, &list);

        const Node = List.Node;
        var nodes: [2]Node = undefined;

        list.insert(.first, &nodes[0]); // same as list.insertFirst(&nodes[0])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));
        try std.testing.expectEqual(null, list.prev(&nodes[0]));

        try verifyConsistency(List, &list);

        list.insertFirst(&nodes[1]); // same as list.insert(.first, &nodes[1])
        try std.testing.expectEqual(&nodes[1], list.first());
        try std.testing.expectEqual(null, list.prev(&nodes[1]));
        try std.testing.expectEqual(&nodes[0], list.next(&nodes[1]));
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.prev(&nodes[0]));

        try verifyConsistency(List, &list);

        var i: u32 = 0;
        var node = list.last();
        while (node) |n| : ({
            node = list.prev(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
    }
}
