const std = @import("std");

pub const Implementation = union(enum) {
    double_linked: DoubleLinked,
    single_linked: SingleLinked,

    pub fn namespace(self: @This()) type {
        return switch (self) {
            inline else => |impl| impl.namespace(),
        };
    }

    pub const DoubleLinked = union(enum) {
        null_terminated: WrapImpl(@import("dbl/null_term.zig")),
        sentinel_terminated: WrapImpl(@import("dbl/sentinel_term.zig")),
        single_ptr: WrapImpl(@import("dbl/single_ptr.zig")),

        fn namespace(self: @This()) type {
            return switch (self) {
                inline else => |impl| impl.namespace(),
            };
        }
    };

    pub const SingleLinked = union(enum) {
        single_ptr: WrapImpl(@import("sgl/single_ptr.zig")),
        double_ptr: WrapImpl(@import("sgl/double_ptr.zig")),

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

comptime {
    std.testing.refAllDecls(@import("dbl/testing.zig"));
    //std.testing.refAllDecls(@import("sgl/testing.zig"));
}
