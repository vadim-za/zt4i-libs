pub fn InsertionPos(Node: type) type {
    return union(enum) {
        first: void,
        last: void,
        before_: *Node,
        after_: *Node,

        pub inline fn before(node: ?*Node) @This() {
            return if (node) |n| .{ .before_ = n } else .last;
        }

        pub inline fn after(node: ?*Node) @This() {
            return if (node) |n| .{ .after_ = n } else .first;
        }
    };
}
