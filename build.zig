const std = @import("std");
const rl = @import("raylib-zig/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const games = [_][:0]const u8{
        "pong",
    };
    for (games) |game| {
        try buildGame(b, game, target, optimize);
    }
}

fn buildGame(b: *std.Build, name: [:0]const u8, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode) !void {
    var raylib = rl.getModule(b, "raylib-zig");
    var raylib_math = rl.math.getModule(b, "raylib-zig");

    const alloc = std.heap.page_allocator;
    const runStepDesc = try std.fmt.allocPrintZ(alloc, "Run {s}", .{name});
    const rootSourcePath = b.pathJoin(&.{ name, "src", "main.zig" });

    //web exports are completely separate
    if (target.getOsTag() == .emscripten) {
        const exe_lib = rl.compileForEmscripten(b, name, rootSourcePath, target, optimize);
        exe_lib.addModule("raylib", raylib);
        exe_lib.addModule("raylib-math", raylib_math);
        const raylib_artifact = rl.getRaylib(b, target, optimize);
        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        exe_lib.linkLibrary(raylib_artifact);
        const link_step = try rl.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rl.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step(name, runStepDesc);
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = rootSourcePath },
        .optimize = optimize,
        .target = target,
    });

    rl.link(b, exe, target, optimize);
    exe.addModule("raylib", raylib);
    exe.addModule("raylib-math", raylib_math);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step(name, runStepDesc);
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
