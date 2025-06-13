const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const z2 = b.addModule(
        "z2",
        .{
            .root_source_file = b.path("z2.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("demo/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.rc_includes = .none;
    demo.root_module.addImport("z2", z2);
    b.installArtifact(demo);
}
