pub const UpdateNode = union(enum) {
    // Don't access fields directly, use methods to construct UpdateNode values
    method_: []const u8,
    Function: type,

    pub const do_nothing = function(doNothing);

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
        ResultType: type,
        Node: type,
        node: *Node,
        left_result: ?ResultType,
        right_result: ?ResultType,
    ) ResultType {
        const callable = switch (self) {
            .method_ => |method_name| @field(Node, method_name),
            .Function => |F| F.update,
        };
        return @call(.auto, callable, .{ node, left_result, right_result });
    }
};

inline fn doNothing(
    node_ptr: anytype,
    left_result: ?void,
    right_result: ?void,
) void {
    _ = node_ptr;
    _ = left_result;
    _ = right_result;
    return {};
}
