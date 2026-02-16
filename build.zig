const std = @import("std");

const LibConfig = struct {
    // Name of lazy dependency
    dep_name: []const u8,
    // Name of library, relative to dependency root
    lib_name: []const u8,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const os_tag = target.result.os.tag;
    const cpu_arch = target.result.cpu.arch;

    const lib_conf: LibConfig = switch (os_tag) {
        .linux => .{
            .dep_name = switch (cpu_arch) {
                .aarch64 => "wasmtime-c-api_aarch64-linux",
                .arm => "wasmtime-c-api_armv7-linux",
                .riscv64 => "wasmtime-c-api_riscv64gc-linux",
                .s390x => "wasmtime-c-api_s390x-linux",
                .x86_64 => "wasmtime-c-api_x86_64-linux",
                else => {
                    std.debug.print("error: invalid CPU arch for {t}: {t}", .{ os_tag, cpu_arch });
                    return error.Target;
                },
            },
            .lib_name = "lib/libwasmtime.a",
        },
        .macos => .{
            .dep_name = switch (cpu_arch) {
                .aarch64 => "wasmtime-c-api_aarch64-macos",
                .x86_64 => "wasmtime-c-api_x86_64-macos",
                else => {
                    std.debug.print("error: invalid CPU arch for {t}: {t}", .{ os_tag, cpu_arch });
                    return error.Target;
                },
            },
            .lib_name = "lib/libwasmtime.a",
        },
        .windows => .{
            .dep_name = switch (cpu_arch) {
                .aarch64 => "wasmtime-c-api_aarch64-windows",
                .x86_64 => "wasmtime-c-api_x86_64-windows",
                else => {
                    std.debug.print("error: invalid CPU arch for {t}: {t}", .{ os_tag, cpu_arch });
                    return error.Target;
                },
            },
            .lib_name = "lib/wasmtime.lib",
        },
        else => {
            std.debug.print("error: invalid OS: {t}", .{os_tag});
            return error.Target;
        },
    };
    std.debug.print("dep_name: '{s}', lib_name: '{s}'\n", .{ lib_conf.dep_name, lib_conf.lib_name });

    const mod = b.addModule("wasmtime_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    if (b.lazyDependency(lib_conf.dep_name, .{})) |dep| {
        mod.addObjectFile(dep.path(lib_conf.lib_name));
    }

    if (b.lazyDependency(lib_conf.dep_name, .{})) |dep| {
        const examples_step = b.step("examples", "Build all examples");

        const example_names: []const []const u8 = &.{
            "hello",
        };

        for (example_names) |name| {
            const example_zig, const example_c = makeExample(b, target, optimize, dep, lib_conf.lib_name, name);
            _ = example_zig;
            // const install_zig = b.addInstallArtifact(example_zig, .{});
            // example_all_step.dependOn(&install_zig.step);
            const install_c = b.addInstallArtifact(example_c, .{});
            examples_step.dependOn(&install_c.step);
        }
    }

    const exe = b.addExecutable(.{
        .name = "wasmtime_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wasmtime_zig", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn makeExample(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, wasmtime_dep: *std.Build.Dependency, lib_name: []const u8, example_name: []const u8) struct { *std.Build.Step.Compile, *std.Build.Step.Compile } {
    const example_c_step = b.step(b.fmt("example_{s}-c", .{example_name}), b.fmt("Build and run the '{s}' example (C)", .{example_name}));
    const c_exe = b.addExecutable(.{
        .name = b.fmt("{s}-c", .{example_name}),
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    c_exe.root_module.addCSourceFile(.{
        .file = b.path(b.fmt("examples/{s}.c", .{example_name})),
    });
    c_exe.addObjectFile(wasmtime_dep.path(lib_name));
    c_exe.addIncludePath(wasmtime_dep.path("include/"));
    c_exe.root_module.linkSystemLibrary("unwind", .{});

    // Extra libraries
    switch (target.result.os.tag) {
        .linux => {
            c_exe.root_module.linkSystemLibrary("pthread", .{ .preferred_link_mode = .static });
            c_exe.root_module.linkSystemLibrary("dl", .{ .preferred_link_mode = .static });
            c_exe.root_module.linkSystemLibrary("m", .{ .preferred_link_mode = .static });
        },
        .macos => {}, // No extra libraries needed
        .windows => {
            c_exe.root_module.linkSystemLibrary("advapi32", .{});
            c_exe.root_module.linkSystemLibrary("userenv", .{});
            c_exe.root_module.linkSystemLibrary("ntdll", .{});
            c_exe.root_module.linkSystemLibrary("shell32", .{});
            c_exe.root_module.linkSystemLibrary("ole32", .{});
            c_exe.root_module.linkSystemLibrary("bcrypt", .{});
        },
        else => @panic("Invalid target OS"),
    }

    const c_run = b.addRunArtifact(c_exe);
    example_c_step.dependOn(&c_run.step);

    return .{ undefined, c_exe };
}
