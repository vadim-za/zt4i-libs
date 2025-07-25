pub const UpdateNode = union(enum) {
    // Don't access fields directly, use methods to construct UpdateNode values
    method_: []const u8,
    Function: type,
    none: void,

    pub const do_nothing = .none;

    pub fn method(name: []const u8) @This() {
        return .{ .method_ = name };
    }

    pub fn function(f: anytype) @This() {
        return .{ .Function = struct {
            const update = f;
        } };
    }

    pub fn call(
        comptime self: @This(),
        Node: type,
        node: *Node,
        children: *[2]?*Node,
    ) void {
        const callable = switch (self) {
            .method_ => |method_name| @field(Node, method_name),
            .Function => |F| F.update,
            .none => return,
        };
        @call(.auto, callable, .{ node, children });
    }
};
