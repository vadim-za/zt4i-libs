const std = @import("std");
const lib = @import("../lib.zig");

const Key = i32;

const tested_configs = configs: {
    var configs: []const lib.sorted_trees.SimpleTreeConfig = &.{};

    for ([_]lib.OwnershipTracking.TrackOwnedItems{
        .container_ptr,
        .{ .custom = i32 },
        .off,
    }) |owned_items| {
        for ([_]lib.OwnershipTracking.TrackFreeItems{
            .off,
            .on,
        }) |free_items| {
            configs = configs ++ [1]lib.sorted_trees.SimpleTreeConfig{.{
                .implementation = .avl,
                .ownership_tracking = .{
                    .owned_items = owned_items,
                    .free_items = free_items,
                },
            }};
        }
    }

    break :configs configs;
};

fn verifyTree(tree_ptr: anytype) void {
    switch (@TypeOf(tree_ptr.*).config.implementation) {
        .avl => @import("avl.zig").verifyTree(tree_ptr),
    }
}

test "Tree basic insertion" {
    inline for (tested_configs) |config| {
        const Tree = lib.SimpleTree(Key, config);

        var tree: Tree = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            tree.setOwnershipToken(1);
        defer tree.deinit();

        verifyTree(&tree);
        try std.testing.expect(!tree.hasContent());
        try std.testing.expectEqual(null, tree.root());
        try std.testing.expectEqual(null, tree.find(&0));

        var node0: Tree.Node = .{ .data = 0 };
        {
            const result = tree.insertNode(&node0, {});
            verifyTree(&tree);
            try std.testing.expect(result.success);
            try std.testing.expectEqual(&node0, result.node);
            try std.testing.expectEqual(&node0, tree.find(&0));
            try std.testing.expectEqual(null, tree.find(&1));
            try std.testing.expectEqual(null, tree.find(&-1));
            try std.testing.expectEqual(&node0, tree.root());
            try std.testing.expectEqual(null, tree.children(&node0)[0]);
            try std.testing.expectEqual(null, tree.children(&node0)[1]);
        }

        var node1: Tree.Node = .{ .data = 10 };
        {
            const result = tree.insertNode(&node1, {});
            verifyTree(&tree);
            try std.testing.expect(result.success);
            try std.testing.expectEqual(&node1, result.node);
            try std.testing.expectEqual(&node0, tree.find(&0));
            try std.testing.expectEqual(&node1, tree.find(&10));
            try std.testing.expectEqual(null, tree.find(&20));
            try std.testing.expectEqual(null, tree.find(&-1));
            try std.testing.expectEqual(null, tree.find(&5));
            if (config.implementation == .avl) {
                try std.testing.expectEqual(&node0, tree.root());
                try std.testing.expectEqual(null, tree.children(&node0)[0]);
                try std.testing.expectEqual(&node1, tree.children(&node0)[1]);
            }
        }

        var node2: Tree.Node = .{ .data = 5 };
        {
            const result = tree.insertNode(&node2, {});
            verifyTree(&tree);
            try std.testing.expect(result.success);
            try std.testing.expectEqual(&node2, result.node);
            try std.testing.expectEqual(&node0, tree.find(&0));
            try std.testing.expectEqual(&node1, tree.find(&10));
            try std.testing.expectEqual(&node2, tree.find(&5));
            try std.testing.expectEqual(null, tree.find(&20));
            try std.testing.expectEqual(null, tree.find(&-1));
            try std.testing.expectEqual(null, tree.find(&3));
            try std.testing.expectEqual(null, tree.find(&9));
            if (config.implementation == .avl) {
                try std.testing.expectEqual(&node2, tree.root());
                try std.testing.expectEqual(&node0, tree.children(&node2)[0]);
                try std.testing.expectEqual(&node1, tree.children(&node2)[1]);
                try std.testing.expectEqual(null, tree.children(&node0)[0]);
                try std.testing.expectEqual(null, tree.children(&node0)[1]);
                try std.testing.expectEqual(null, tree.children(&node1)[0]);
                try std.testing.expectEqual(null, tree.children(&node1)[1]);
            }
        }

        try std.testing.expectEqual(&node2, tree.remove(&node2, {}));
        verifyTree(&tree);
        // The root now may be node0 or node1, it is unspecified

        tree.removeAll();
        verifyTree(&tree);
    }
}

test "Tree random" {
    inline for (tested_configs) |config| {
        const Tree = lib.SimpleTreeMap(Key, ?usize, config);

        var tree: Tree = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            tree.setOwnershipToken(1);
        defer tree.deinit();

        verifyTree(&tree);

        var nodes: [1000]Tree.Node = undefined;
        var rng = std.Random.DefaultPrng.init(0);
        var inserted_count: usize = 0;

        // Randomly populate the tree
        for (&nodes) |*node| {
            // make sure there are less keys than nodes
            node.key = rng.random().intRangeAtMost(i32, 0, (nodes.len * 9) / 10);
            node.data = null;
            const result = tree.insertNode(node, {});
            if (result.success) {
                try std.testing.expectEqual(node, result.node);
                node.data = 0;
                inserted_count += 1;
            } else {
                try std.testing.expect(node != result.node);
                try std.testing.expectEqual(node.key, result.node.key);
            }
            verifyTree(&tree);
        }
        std.debug.assert(inserted_count > 100); // otherwise smth wrong with rng
        std.debug.assert(inserted_count < nodes.len);

        // Check that the tree contains those and only those nodes
        // that have been reported to be successfully inserted.
        for (&nodes) |*node| {
            const result = tree.find(&node.key);
            try std.testing.expectEqual(
                node.data != null,
                result == node,
            );
        }

        // Remove nodes in random order
        var permuted_keys: [nodes.len]i32 = undefined;
        for (&nodes, &permuted_keys) |*node, *key|
            key.* = node.key;
        for (0..nodes.len) |_| {
            const idx1 = rng.random().intRangeLessThan(usize, 0, nodes.len);
            const idx2 = rng.random().intRangeLessThan(usize, 0, nodes.len);
            std.mem.swap(i32, &permuted_keys[idx1], &permuted_keys[idx2]);
        }

        for (&permuted_keys) |key| {
            const find_result = tree.find(&key);
            const remove_result = tree.remove(&key, {});

            try std.testing.expectEqual(find_result, remove_result);
            if (remove_result) |node| {
                try std.testing.expectEqual(key, node.key);
                inserted_count -= 1;
            }

            verifyTree(&tree);

            // Leave a few nodes for removeAll()
            //if (inserted_count <= 10)
            //    break;
        }

        tree.removeAll();
        try std.testing.expectEqual(null, tree.root());
    }
}
