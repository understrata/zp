const std = @import("std");

pub fn runProcess(io: std.Io, argv: []const []const u8, cwd: []const u8) !void {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .cwd = .{ .path = cwd },
        .stdout = .inherit,
        .stderr = .inherit,
        .stdin = .inherit,
    });
    _ = try child.wait(io);
}

pub fn ensureDir(io: std.Io, path: []const u8) !void {
    std.Io.Dir.cwd().createDir(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

test "ensureDir creates and tolerates an existing directory" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, ".zig-cache/tmp/{s}/dir", .{tmp.sub_path});

    try ensureDir(io, path);
    try ensureDir(io, path);
    try std.Io.Dir.cwd().deleteDir(io, path);
}
