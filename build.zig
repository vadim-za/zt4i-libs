const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zt4i = b.addModule(
        "zt4i",
        .{
            .root_source_file = b.path("zt4i.zig"),
        },
    );

    const zt4i_tests = b.addTest(.{
        .root_source_file = b.path("zt4i.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_zt4i_tests = b.addRunArtifact(zt4i_tests);

    if (target.result.os.tag == .windows) {
        const demo = b.addExecutable(.{
            .name = "demo",
            .root_source_file = b.path("demo/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        demo.rc_includes = .none;
        demo.addWin32ResourceFile(.{ .file = b.path("demo/resources/demo.rc") });
        demo.root_module.addImport("zt4i", zt4i);
        demo.subsystem = .Windows;
        b.installArtifact(demo);
    }

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_zt4i_tests.step);
}
