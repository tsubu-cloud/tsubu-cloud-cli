const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // wasmtime ships no pkg-config file, so its include/lib directories are
    // supplied explicitly (e.g. from the Nix package's `dev`/`lib` outputs).
    // Forwarded straight through to the tsubu-cloud-core dependency, which
    // is the one that actually links against wasmtime/libpq.
    const wasmtime_include_dir = b.option([]const u8, "wasmtime-include", "Path to wasmtime's include directory") orelse "";
    const wasmtime_lib_dir = b.option([]const u8, "wasmtime-lib", "Path to wasmtime's lib directory") orelse "";
    const pq_lib_dir = b.option([]const u8, "pq-lib", "Path to libpq's lib directory") orelse "";
    const lzma_lib_dir = b.option([]const u8, "lzma-lib", "Path to liblzma's lib directory") orelse "";

    const core_dep = b.dependency("tsubu_cloud_core", .{
        .target = target,
        .optimize = optimize,
        .@"wasmtime-include" = wasmtime_include_dir,
        .@"wasmtime-lib" = wasmtime_lib_dir,
        .@"pq-lib" = pq_lib_dir,
        .@"lzma-lib" = lzma_lib_dir,
    });
    const core_mod = core_dep.module("core");

    const exe = b.addExecutable(.{
        .name = "tsubu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("core", core_mod);
    exe.linkage = .static;
    b.installArtifact(exe);

    const run_step = b.step("run", "Run tsubu");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
