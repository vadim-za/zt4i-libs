const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const paw = b.createModule(.{
        .root_source_file = b.path("paw/paw.zig"),
        .target = target,
        .optimize = optimize,
    });

    const z2 = b.addModule(
        "z2",
        .{
            .root_source_file = b.path("z2.zig"),
            .target = target,
            .optimize = optimize,
        },
    );
    z2.addImport("paw", paw);

    paw.addImport("z2", z2);

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
