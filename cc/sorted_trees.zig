const std = @import("std");
const lib = @import("lib.zig");
const impl = @import("sorted_trees/impl.zig");
const CompareTo = @import("sorted_trees/compare_to.zig").CompareTo;
const UpdateNode = @import("sorted_trees/update_node.zig").UpdateNode;

pub const Implementation = impl.Implementation;

pub const Config = struct {
    implementation: Implementation,
    hook_field: []const u8,
    compare_to: CompareTo,
    update_node: UpdateNode = .do_nothing,
    ownership_tracking: lib.OwnershipTracking,
};

pub fn Tree(Node: type, cfg: Config) type {
    return cfg.implementation.namespace().Tree(
        Node,
        cfg.hook_field,
        cfg.compare_to,
        cfg.update_node,
        cfg.ownership_tracking,
    );
}

pub const SimpleTreeConfig = struct {
    implementation: Implementation,
    compare_to: CompareTo = .default,
    ownership_tracking: lib.OwnershipTracking,
};

pub fn SimpleTree(Payload: type, cfg: SimpleTreeConfig) type {
    const Decls = struct {
        const Node = struct {
            data: Payload,
            hook: Tree_.Hook = .{},
        };

        const cfg_ = Config{
            .implementation = cfg.implementation,
            .hook_field = "hook",
            .compare_to = .useField("data", cfg.compare_to),
            .ownership_tracking = cfg.ownership_tracking,
        };

        const Tree_ = Tree(Node, cfg_);
    };

    return Decls.Tree_;
}

comptime {
    std.testing.refAllDecls(impl);
}

// -----------------------------------------------------------------------

// This test serves more like a minimal sorted tree demo.
// More in-depth testing is done in sorted_trees/testing.zig
test "Simple tree demo" {
    // A list with an i32 payload
    const T = SimpleTree(i32, .{
        .implementation = .avl,
        .ownership_tracking = .{
            // Track node ownership in debug builds using pointers to the list object.
            // Ownership tracking prevents inadvertent incorrect pairing of a node
            // with a list which doesn't own it (e.g. it list iteration or node removal).
            .owned_items = .container_ptr,

            // Track free items status, so that one cannot inadvertently insert
            // an already inserted item into anothe rlist.
            .free_items = .on,
        },
    });

    var t: T = .{};

    try std.testing.expectEqual(null, t.find(&0));

    const Inserter = struct {
        node: *T.Node,
        pub fn key(self: *const @This()) *i32 {
            return &self.node.data;
        }
        pub fn produceNode(self: *const @This()) *T.Node {
            return self.node;
        }
    };
    var n0: T.Node = .{ .data = 0 };
    {
        const result = t.insert(Inserter{ .node = &n0 });
        try std.testing.expect(result.success);
        try std.testing.expectEqual(&n0, result.node);
    }
}
