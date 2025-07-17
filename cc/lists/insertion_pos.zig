pub fn InsertionPos(Node: type) type {
    return union(enum) {
        first: void,
        last: void,
        before_: *Node,
        after_: *Node,

        pub fn before(node: *Node) @This() {
            return .{ .before_ = node };
        }

        pub fn after(node: *Node) @This() {
            return .{ .after_ = node };
        }
    };
}
