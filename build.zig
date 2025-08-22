const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    Ensure_Zig_Version() catch @panic("Zig 0.15.1 is required for compilation!");

    const target = b.standardTargetOptions(.{});
    const options = b.addOptions();

    const src_filepath = "src/";
    const main_filepath = src_filepath ++ "main.zig";
    const tests_filepath = src_filepath ++ "tests.zig";

    // "-Dgenerate_gif=[true/false]"
    const generate_gif = b.option(bool, "generate_gif", "Generate the sceenshots for the Demo gif.") orelse false;
    options.addOption(bool, "generate_gif", generate_gif);

    // add executable
    const exe = b.addExecutable(.{
        .name = "heatmap",
        .root_module = b.createModule(.{
            .root_source_file = b.path(main_filepath),
            .target = target,
            .optimize = .ReleaseFast,
        }),
        .use_llvm = true,
    });
    exe.root_module.addOptions("build_options", options);
    exe.linkSystemLibrary("raylib");
    exe.linkLibC();
    b.installArtifact(exe);

    // unit testing
    const added_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(tests_filepath),
            .target = target,
        }),
    });
    const performStep_test = b.addRunArtifact(added_tests);
    b.default_step.dependOn(&performStep_test.step);

    // run executable
    var run_step = b.step("run", "Run the executable");
    const performStep_run = b.addRunArtifact(exe);
    if (b.args) |args|
        performStep_run.addArgs(args);
    run_step.dependOn(&performStep_run.step);

    // format source files
    const format_options = std.Build.Step.Fmt.Options{ .paths = &.{src_filepath} };
    const performStep_format = b.addFmt(format_options);
    b.default_step.dependOn(&performStep_format.step);
}

/// Requires exactly Zig 0.15.1
pub fn Ensure_Zig_Version() !void {
    const current_version = builtin.zig_version;
    const required_version = std.SemanticVersion{
        .major = 0,
        .minor = 15,
        .patch = 1,
        .build = null,
        .pre = null,
    };
    switch (std.SemanticVersion.order(current_version, required_version)) {
        .lt => return error.OutdatedVersion,
        .eq => {},
        .gt => return error.FutureDatedVersion,
    }
}
