const std = @import("std");
const lib = @import("../../lib.zig");

const Payload = i32;

const tested_configs = tested_configs_all;

const tested_configs_none: []const lib.lists.Config = &.{};

const tested_configs_all = configs: {
    var configs: []const lib.lists.Config = &.{};

    for ([_]std.meta.Tag(lib.lists.Implementation.DoubleLinked){
        .null_terminated,
        //.sentinel_terminated,
        //.single_ptr,
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
                configs = configs ++ [1]lib.lists.Config{.{
                    .implementation = .{ .double_linked = impl },
                    .layout = .simple_payload,
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

fn verifyConsistency(List: type, list: *List) !void {
    try std.testing.expectEqual(list.hasContent(), list.first() != null);
    try std.testing.expectEqual(list.hasContent(), list.last() != null);

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
        if (impl == .sentinel_terminated)
            list.init();
        if (comptime config.ownership_tracking.owned_items == .custom)
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
        try std.testing.expectEqual(2, i);
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
        if (impl == .sentinel_terminated)
            list.init();
        if (comptime config.ownership_tracking.owned_items == .custom)
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
        try std.testing.expectEqual(2, i);
    }
}

test "insertBefore" {
    inline for (tested_configs) |config| {
        const List = lib.lists.List(Payload, config);
        const impl = comptime config.implementation.double_linked;
        var list: List = if (impl == .sentinel_terminated)
            undefined
        else
            .{};
        list.init(); // redundant if .{} initialization is done above
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);

        try verifyConsistency(List, &list);

        const Node = List.Node;
        var nodes: [4]Node = undefined;

        // Same as list.insertLast()
        list.insert(.before(null), &nodes[2]); // 2
        try verifyConsistency(List, &list);

        // Same as list.insertBefore(&nodes[2], &nodes[0]);
        list.insert(.before(&nodes[2]), &nodes[0]); // 0 2
        try verifyConsistency(List, &list);

        list.insertBefore(&nodes[2], &nodes[1]); // 0 1 2
        try verifyConsistency(List, &list);

        list.insert(.before(null), &nodes[3]); // 0 1 2 3
        try verifyConsistency(List, &list);

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
        try std.testing.expectEqual(4, i);
    }
}

test "insertAfter" {
    inline for (tested_configs) |config| {
        const List = lib.lists.List(Payload, config);
        const impl = comptime config.implementation.double_linked;
        var list: List = if (impl == .sentinel_terminated)
            undefined
        else
            .{};
        list.init(); // redundant if .{} initialization is done above
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);

        try verifyConsistency(List, &list);

        const Node = List.Node;
        var nodes: [4]Node = undefined;

        // Same as list.insertFirst()
        list.insert(.after(null), &nodes[1]); // 1
        try verifyConsistency(List, &list);

        // Same as list.insertAfter(&nodes[1], &nodes[3]);
        list.insert(.after(&nodes[1]), &nodes[3]); // 1 3
        try verifyConsistency(List, &list);

        list.insertAfter(&nodes[1], &nodes[2]); // 1 2 3
        try verifyConsistency(List, &list);

        list.insert(.after(null), &nodes[0]); // 0 1 2 3
        try verifyConsistency(List, &list);

        var i: u32 = 0;
        var node = list.first();
        while (node) |n| : ({
            node = list.next(n);
            i += 1;
        })
            try std.testing.expectEqual(&nodes[i], n);
        try std.testing.expectEqual(4, i);
    }
}

test "remove" {
    inline for (tested_configs) |config| {
        const List = lib.lists.List(Payload, config);
        const impl = comptime config.implementation.double_linked;
        var list: List = if (impl == .sentinel_terminated)
            undefined
        else
            .{};
        list.init(); // redundant if .{} initialization is done above
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);

        try verifyConsistency(List, &list);

        const Node = List.Node;
        var nodes: [3]Node = undefined;

        // remove first node

        for (&nodes) |*node|
            list.insertLast(node);
        try verifyConsistency(List, &list);

        list.remove(&nodes[0]);
        try verifyConsistency(List, &list);
        try std.testing.expectEqual(&nodes[1], list.first());
        try std.testing.expectEqual(&nodes[2], list.last());

        try std.testing.expectEqual(&nodes[1], list.popFirst());
        try std.testing.expectEqual(&nodes[2], list.popFirst());
        try std.testing.expectEqual(null, list.popFirst());
        try std.testing.expect(!list.hasContent());

        // remove last node

        for (&nodes) |*node|
            list.insertLast(node);
        try verifyConsistency(List, &list);

        list.remove(&nodes[2]);
        try verifyConsistency(List, &list);
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[1], list.last());

        try std.testing.expectEqual(&nodes[1], list.popLast());
        try std.testing.expectEqual(&nodes[0], list.popLast());
        try std.testing.expectEqual(null, list.popLast());
        try std.testing.expect(!list.hasContent());

        // remove middle node

        for (&nodes) |*node|
            list.insertLast(node);
        try verifyConsistency(List, &list);

        list.remove(&nodes[1]);
        try verifyConsistency(List, &list);
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[2], list.last());

        list.remove(&nodes[0]);
        list.remove(&nodes[2]);
        try std.testing.expect(!list.hasContent());
    }
}

test "Embedded hook" {
    inline for (tested_configs) |base_config| {
        comptime var config = base_config;
        config.layout = comptime .{ .embedded_hook = "hook" };

        const types = struct {
            const List = lib.lists.List(Node, config);
            const Node = struct {
                data: Payload,
                hook: List.Hook,
            };
        };
        const impl = comptime config.implementation.double_linked;
        var list: types.List = if (impl == .sentinel_terminated)
            undefined
        else
            .{};
        list.init(); // redundant if .{} initialization is done above
        if (comptime config.ownership_tracking.owned_items == .custom)
            list.setOwnershipToken(1);

        try verifyConsistency(types.List, &list);

        var node: types.Node = undefined;

        list.insertFirst(&node);
        try verifyConsistency(types.List, &list);

        list.remove(&node);
        try verifyConsistency(types.List, &list);
    }
}

test "Non-empty layout" {
    // Layout can be configured at runtime to one of two different hooks
    // specified using the 'index' field
    const Layout = struct {
        pub fn With(Node_: type, Hook: type) type {
            return struct {
                pub const Node = Node_;

                index: usize = undefined,

                /// This function is required by all implementations
                pub fn hookFromNode(
                    self: @This(),
                    node: *const Node,
                ) *const Hook {
                    return &node.hooks[self.index];
                }

                /// This function is required by some but not all implementations
                pub fn nodeFromHook(
                    self: @This(),
                    hook: *const Hook,
                ) *const Node {
                    const hook0 = hook[0..1].ptr - self.index;
                    const hooks: *const [2]Hook = @ptrCast(hook0);
                    return @alignCast(@fieldParentPtr("hooks", hooks));
                }
            };
        }
    };

    inline for (tested_configs) |base_config| {
        comptime var config = base_config;
        config.layout = comptime .{ .custom = Layout };

        const types = struct {
            const List = lib.lists.List(Node, config);
            const Node = struct {
                data: Payload,
                hooks: [2]List.Hook,
            };
        };

        for (0..2) |index| {
            var list: types.List = undefined;
            list.init();
            list.layout = .{ .index = index };
            if (comptime config.ownership_tracking.owned_items == .custom)
                list.setOwnershipToken(1);

            try verifyConsistency(types.List, &list);

            var node: types.Node = undefined;

            list.insertFirst(&node);
            try verifyConsistency(types.List, &list);

            list.remove(&node);
            try verifyConsistency(types.List, &list);
        }
    }
}
