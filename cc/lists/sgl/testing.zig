const std = @import("std");
const lib = @import("../../lib.zig");

const Payload = i32;

const tested_configs = configs: {
    var configs: []const lib.lists.SimpleListConfig = &.{};

    for ([_]std.meta.Tag(lib.lists.Implementation.SingleLinked){
        .single_ptr,
        .double_ptr,
    }) |impl| {
        for ([_]lib.OwnershipTracking.TrackOwnedItems{
            .container_ptr,
            .{ .custom = i32 },
            .off,
        }) |owned_items| {
            for ([_]lib.OwnershipTracking.TrackFreeItems{
                .off,
                .on,
            }) |free_items| {
                configs = configs ++ [1]lib.lists.SimpleListConfig{.{
                    .implementation = .{ .single_linked = impl },
                    .ownership_tracking = .{
                        .owned_items = owned_items,
                        .free_items = free_items,
                    },
                }};
            }
        }
    }

    break :configs configs;
};

test "insertFirst" {
    inline for (tested_configs) |config| {
        const List = lib.SimpleList(Payload, config);
        var list: List = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);
        defer list.deinit();

        const Node = List.Node;
        var nodes: [2]Node = if (comptime config.ownership_tracking.free_items != .off)
            [1]Node{.{ .data = undefined }} ** 2
        else
            undefined;

        list.insert(.first, &nodes[1]); // same as list.insertFirst(&nodes[1])
        try std.testing.expectEqual(&nodes[1], list.first());
        try std.testing.expectEqual(null, list.next(&nodes[1]));

        list.insertFirst(&nodes[0]); // same as list.insert(.first, &nodes[0])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[1], list.next(&nodes[0]));
        try std.testing.expectEqual(null, list.next(&nodes[1]));

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
        try std.testing.expectEqual(2, i);

        if (comptime config.ownership_tracking.free_items != .off)
            list.removeAll();
    }
}

test "insertLast" {
    inline for (tested_configs) |config| {
        const List = lib.SimpleList(Payload, config);
        const impl = comptime config.implementation.single_linked;
        if (impl == .single_ptr) continue;

        var list: List = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);
        defer list.deinit();

        const Node = List.Node;
        var nodes: [2]Node = undefined;
        if (comptime config.ownership_tracking.free_items != .off) {
            for (&nodes) |*n| n.* = .{ .data = undefined };
        }

        list.insert(.last, &nodes[0]); // same as list.insertLast(&nodes[0])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));

        list.insertLast(&nodes[1]); // same as list.insert(.last, &nodes[1])
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[1], list.next(&nodes[0]));
        try std.testing.expectEqual(&nodes[1], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[1]));

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
        try std.testing.expectEqual(2, i);

        if (comptime config.ownership_tracking.free_items != .off)
            list.removeAll();
    }
}

test "insertAfter" {
    inline for (tested_configs) |config| {
        const List = lib.SimpleList(Payload, config);
        var list: List = undefined;
        list.init();
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);
        defer list.deinit();

        const Node = List.Node;
        var nodes: [4]Node = undefined;
        if (comptime config.ownership_tracking.free_items != .off) {
            for (&nodes) |*n| n.* = .{ .data = undefined };
        }

        // Same as list.insertFirst()
        list.insert(.after(null), &nodes[1]); // 1

        // Same as list.insertAfter(&nodes[1], &nodes[3]);
        list.insert(.after(&nodes[1]), &nodes[3]); // 1 3

        list.insertAfter(&nodes[1], &nodes[2]); // 1 2 3

        list.insert(.after(null), &nodes[0]); // 0 1 2 3

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
        try std.testing.expectEqual(4, i);

        if (comptime config.ownership_tracking.free_items != .off)
            list.removeAll();
    }
}

test "removeFirst" {
    inline for (tested_configs) |config| {
        const List = lib.SimpleList(Payload, config);
        var list: List = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);
        defer list.deinit();

        const Node = List.Node;
        var nodes: [3]Node = undefined;
        if (comptime config.ownership_tracking.free_items != .off) {
            for (&nodes) |*n| n.* = .{ .data = undefined };
        }

        // remove first node

        for (&nodes) |*node|
            list.insertFirst(node);

        list.removeFirst();
        try std.testing.expectEqual(&nodes[1], list.first());
        try std.testing.expectEqual(&nodes[0], list.next(&nodes[1]));

        try std.testing.expectEqual(&nodes[1], list.popFirst());
        try std.testing.expectEqual(&nodes[0], list.popFirst());
        try std.testing.expectEqual(null, list.popFirst());
        try std.testing.expect(!list.hasContent());
    }
}

test "Primary API" {
    inline for (tested_configs) |simple_config| {
        const config = lib.lists.Config{
            .implementation = simple_config.implementation,
            .hook_field = "hook",
            .ownership_tracking = simple_config.ownership_tracking,
        };

        const types = struct {
            const List = lib.lists.List(Node, config);
            const Node = struct {
                data: Payload = undefined,
                hook: List.Hook = .{},
            };
        };
        var list: types.List = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);
        defer list.deinit();

        var node: types.Node = .{};

        list.insertFirst(&node);
        list.removeFirst();

        // There were no expect() calls, but the test checks that the code
        // doesn't raise any assertions.
    }
}
