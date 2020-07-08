const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const build_v7m_docs = b.addSystemCommand(&[_][]const u8{
        b.zig_exe,
        "test",
        "v7m.zig",
        "-target",
        "arm-linux-eabihf", // must use arm-linux in order for tests to build
        "-mcpu=cortex_m7",
        "-femit-docs",
        "-fno-emit-bin",
        "--output-dir",
        ".",
    });

    b.default_step.dependOn(&build_v7m_docs.step);
}
