const std = @import("std");
const fs = std.fs;
const zecsi = @import("src/zecsi/build.zig");

pub const APP_NAME = "zecsi-examples";

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    switch (target.getOsTag()) {
        .wasi, .emscripten => {
            try zecsi.installEmscripten(b, b.addStaticLibrary(.{
                .name = APP_NAME,
                .root_source_file = std.build.FileSource.relative("src/web.zig"),
                .optimize = mode,
                .target = target,
            }));
        },
        else => {
            std.log.info("building for desktop\n", .{});
            const exe = b.addExecutable(.{
                .name = APP_NAME,
                .root_source_file = std.build.FileSource.relative("src/desktop.zig"),
                .optimize = mode,
                .target = target,
            });

            try zecsi.addZecsiDesktop(b, exe);

            b.installArtifact(exe);

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);

            const exe_tests = b.addTest(.{
                .root_source_file = .{ .path = "src/tests.zig" },
                .target = target,
                .optimize = mode,
                .link_libc = true,
            });
            const raylib = @import("src/zecsi/src/raylib/build.zig");
            raylib.addTo(b, exe_tests, exe_tests.target, exe_tests.optimize, .{});

            const test_step = b.step("test", "Run unit tests");
            test_step.dependOn(&exe_tests.step);
        },
    }
}
