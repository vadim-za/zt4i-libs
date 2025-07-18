pub const Implementation = union(enum) {
    double_linked: DoubleLinked,

    pub fn namespace(self: @This()) type {
        return switch (self) {
            inline else => |impl| impl.namespace(),
        };
    }

    pub const DoubleLinked = union(enum) {
        null_terminated: WrapImpl(@import("dbl/null_term.zig")),
        // sentinel_terminated: WrapImpl(@import("dbl/sentinel_term.zig")),
        single_ptr: WrapImpl(@import("dbl/single_ptr.zig")),

        fn namespace(self: @This()) type {
            return switch (self) {
                inline else => |impl| impl.namespace(),
            };
        }
    };
};

fn WrapImpl(impl_namespace: type) type {
    return struct {
        fn namespace(_: @This()) type {
            return impl_namespace;
        }
    };
}
