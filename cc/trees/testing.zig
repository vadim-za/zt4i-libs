const std = @import("std");
const lib = @import("../lib.zig");

const Key = i32;

const tested_configs = configs: {
    var configs: []const lib.trees.SimpleTreeConfig = &.{};

    for ([_]lib.OwnershipTracking.TrackOwnedItems{
        .container_ptr,
        .{ .custom = i32 },
        .off,
    }) |owned_items| {
        for ([_]lib.OwnershipTracking.TrackFreeItems{
            .off,
            .on,
        }) |free_items| {
            configs = configs ++ [1]lib.trees.SimpleTreeConfig{.{
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

fn verifyTree(tree_ptr: anytype) !void {
    return switch (@TypeOf(tree_ptr.*).config.implementation) {
        .avl => @import("avl.zig").verifyTree(tree_ptr),
    };
}

test "Tree basic" {
    inline for (tested_configs) |config| {
        const Tree = lib.SimpleTree(Key, config);

        var tree: Tree = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            tree.setOwnershipToken(1);
        defer tree.deinit();

        try verifyTree(&tree);
        try std.testing.expect(!tree.hasContent());
        try std.testing.expectEqual(null, tree.root());
        try std.testing.expectEqual(null, tree.find(&0));

        var node0: Tree.Node = .{ .data = 0 };
        {
            const result = tree.insertNode(&node0, .{});
            try verifyTree(&tree);
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
            const result = tree.insertNode(&node1, .{});
            try verifyTree(&tree);
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
            const result = tree.insertNode(&node2, .{});
            try verifyTree(&tree);
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

        try std.testing.expectEqual(&node2, tree.remove(&node2, .{}));
        try verifyTree(&tree);
        // The root now may be node0 or node1, it is unspecified

        tree.removeAll(.{});
        try verifyTree(&tree);
    }
}

test "Tree map basic" {
    inline for (tested_configs) |config| {
        const Tree = lib.SimpleTreeMap(Key, void, config);

        var tree: Tree = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            tree.setOwnershipToken(1);
        defer tree.deinit();

        try verifyTree(&tree);
        try std.testing.expect(!tree.hasContent());
        try std.testing.expectEqual(null, tree.root());
        try std.testing.expectEqual(null, tree.find(&0));

        var node0: Tree.Node = .{ .key = 0, .data = {} };
        {
            const result = tree.insertNode(&node0, .{});
            try verifyTree(&tree);
            try std.testing.expect(result.success);
            try std.testing.expectEqual(&node0, result.node);
            try std.testing.expectEqual(&node0, tree.find(&0));
            try std.testing.expectEqual(null, tree.find(&1));
            try std.testing.expectEqual(null, tree.find(&-1));
            try std.testing.expectEqual(&node0, tree.root());
            try std.testing.expectEqual(null, tree.children(&node0)[0]);
            try std.testing.expectEqual(null, tree.children(&node0)[1]);
        }

        var node1: Tree.Node = .{ .key = 10, .data = {} };
        {
            const result = tree.insertNode(&node1, .{});
            try verifyTree(&tree);
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

        var node2: Tree.Node = .{ .key = 5, .data = {} };
        {
            const result = tree.insertNode(&node2, .{});
            try verifyTree(&tree);
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

        try std.testing.expectEqual(&node2, tree.remove(&node2, .{}));
        try verifyTree(&tree);
        // The root now may be node0 or node1, it is unspecified

        tree.removeAll(.{});
        try verifyTree(&tree);
    }
}

test "Tree random" {
    inline for (tested_configs) |simple_config| {
        const Decls = struct {
            const Node = struct {
                hook: Tree.Hook = .{},
                key: Key,
                data: ?usize,
            };
            const config = lib.trees.Config{
                .implementation = simple_config.implementation,
                .hook_field = "hook",
                .compare_to = .useField("key", simple_config.compare_to),
                .ownership_tracking = simple_config.ownership_tracking,
            };
            const Tree = lib.Tree(Node, config);
        };
        const Tree = Decls.Tree;
        const config = Decls.config;

        const Retracer = struct {
            pub fn retrace(
                _: *const @This(),
                node: *Tree.Node,
                children: *const [2]?*Tree.Node,
            ) void {
                freeRetrace(node, children);
            }

            fn freeRetrace(
                node: *Tree.Node,
                children: *const [2]?*Tree.Node,
            ) void {
                node.data = 1 +
                    (if (children[0]) |ch| ch.data.? else 0) +
                    (if (children[1]) |ch| ch.data.? else 0);
            }

            fn verifyUnder(tree_: *Tree, node: ?*Tree.Node) !void {
                const n = node orelse return;
                const children = tree_.children(n);
                try verifyUnder(tree_, children[0]);
                try verifyUnder(tree_, children[1]);
                try std.testing.expectEqual(1 +
                    (if (children[0]) |ch| ch.data.? else 0) +
                    (if (children[1]) |ch| ch.data.? else 0), n.data);
            }
        };
        const retracer = Retracer{};
        const retracer_tuple = .{ Retracer.freeRetrace, .{} };

        var tree: Tree = .{};
        if (comptime config.ownership_tracking.owned_items == .custom)
            tree.setOwnershipToken(1);
        defer tree.deinit();

        try verifyTree(&tree);

        var nodes: [1000]Tree.Node = undefined;
        var rng = std.Random.DefaultPrng.init(0);
        var inserted_count: usize = 0;

        // Randomly populate the tree
        for (&nodes) |*node| {
            // Initialize the node in its entirety,
            // or at least default-initialize the hook!
            node.* = .{
                // make sure there are less keys than nodes
                .key = rng.random().intRangeAtMost(i32, 0, (nodes.len * 9) / 10),
                .data = null,
            };
            const result = if (inserted_count & 1 == 0)
                tree.insertNode(node, .{ .retracer = retracer })
            else
                tree.insertNode(node, .{ .retracer = retracer_tuple });
            if (result.success) {
                try std.testing.expectEqual(node, result.node);
                inserted_count += 1;
            } else {
                try std.testing.expect(node != result.node);
                try std.testing.expectEqual(node.key, result.node.key);
            }
            try verifyTree(&tree);
            try Retracer.verifyUnder(&tree, tree.root());
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
            const remove_result = if (inserted_count & 1 == 0)
                tree.remove(&key, .{ .retracer = retracer_tuple })
            else
                tree.remove(&key, .{ .retracer = retracer });

            try std.testing.expectEqual(find_result, remove_result);
            if (remove_result) |node| {
                try std.testing.expectEqual(key, node.key);
                inserted_count -= 1;
            }

            try verifyTree(&tree);
            try Retracer.verifyUnder(&tree, tree.root());

            // Leave a few nodes for removeAll()
            if (inserted_count <= 10)
                break;
        }

        // Remove the remaining nodes using removeAll()
        const Discarder = struct {
            fn freeDiscard(inserted_count_ptr: *usize, _: *Tree.Node) void {
                inserted_count_ptr.* -= 1;
            }
        };

        tree.removeAll(.{ .discarder = &.{
            Discarder.freeDiscard,
            .{&inserted_count},
        } });
        try std.testing.expectEqual(null, tree.root());
        // Check that discarder worked
        try std.testing.expectEqual(0, inserted_count);
    }
}

test "Failing inserter" {
    const Tree = lib.SimpleTree(i32, .{
        .implementation = .avl,
        .ownership_tracking = .{
            .owned_items = .container_ptr,
            .free_items = .on,
        },
    });

    var tree: Tree = .{};
    defer {
        tree.removeAll(.{});
        tree.deinit();
    }

    const Inserter = struct {
        node: ?*Tree.Node,

        fn init(node: *Tree.Node, success: bool) @This() {
            return .{
                .node = if (success) node else null,
            };
        }

        pub fn produceNode(self: *const @This()) !*Tree.Node {
            return self.node orelse error.OutOfMemory;
        }
    };

    var node = Tree.Node{ .data = 0 };

    // Failing inserter
    try std.testing.expectError(
        error.OutOfMemory,
        tree.insert(
            &node,
            .{ .inserter = Inserter.init(&node, false) },
        ),
    );

    // Alright, let's really insert
    {
        const result = try tree.insert(
            &node,
            .{ .inserter = Inserter.init(&node, true) },
        );
        try std.testing.expect(result.success);
        try std.testing.expectEqual(&node, result.node);
    }

    // Try to insert a duplicate
    var node1 = Tree.Node{ .data = 0 };
    {
        const result = try tree.insert(
            &node1,
            .{ .inserter = Inserter.init(&node1, true) },
        );
        try std.testing.expect(!result.success);
        try std.testing.expectEqual(&node, result.node);
    }
}
