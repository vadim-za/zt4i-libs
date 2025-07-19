pub fn Methods(Container: type) type {
    return struct {
        const Node = Container.Node;

        pub fn popFirst(self: *Container) ?*Node {
            if (self.first()) |node| {
                self.remove(node);
                return node;
            }
            return null;
        }

        pub fn popLast(self: *Container) ?*Node {
            if (self.last()) |node| {
                self.remove(node);
                return node;
            }
            return null;
        }

        pub fn removeAll(self: *Container) void {
            while (self.last()) |node|
                self.remove(node);
        }
    };
}
