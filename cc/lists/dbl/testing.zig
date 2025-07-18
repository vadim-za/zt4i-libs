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

test "Basic" {
    inline for (tested_configs) |config| {
        const List = lib.lists.List(Payload, config);
        var list: List = undefined;
        list.init();

        const Node = List.Node;
        var nodes: [2]Node = undefined;

        list.insertLast(&nodes[0]);
        try std.testing.expectEqual(&nodes[0], list.first());
        try std.testing.expectEqual(&nodes[0], list.last());
        try std.testing.expectEqual(null, list.next(&nodes[0]));
        try std.testing.expectEqual(null, list.prev(&nodes[0]));
    }

    @breakpoint();
}
