const std = @import("std");
const p = @import("../parser.zig");

pub fn list(init: std.process.Init, allocator: std.mem.Allocator) !void {
    var buffer: [8096]u8 = undefined;
    const names = try p.getInstalledPkgs(init.io, p.install_db_path, &buffer, allocator);
    if (names.items.len == 0) {
        std.debug.print("No pkgs installed.\n", .{});
    } else {
        for (names.items) |name| {
            std.debug.print("{s}\n", .{name});
        }
    }
}
