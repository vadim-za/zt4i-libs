const std = @import("std");

pub const Implementation = union(enum) {
    avl: WrapImpl(@import("avl.zig")),

    pub fn namespace(self: @This()) type {
        return switch (self) {
            inline else => |impl| impl.namespace(),
        };
    }
};

fn WrapImpl(impl_namespace: type) type {
    return struct {
        fn namespace(_: @This()) type {
            return impl_namespace;
        }
    };
}

comptime {
    std.testing.refAllDecls(@import("testing.zig"));
}
