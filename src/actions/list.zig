const std = @import("std");
const p = @import("../parser.zig");

pub fn list(allocator: std.mem.Allocator) !void {
    var massive: std.ArrayList([]const u8) = try p.GetInstalledPkgs(allocator);

    defer {
        for (massive.items) |i| {
            allocator.free(i);
        }
        massive.deinit(allocator);
    }

    if (massive.items.len == 0) {
        std.debug.print("No pkgs installed.\n", .{});
    } else {
        for (massive.items) |i| {
            std.debug.print("{s}\n", .{i});
        }
    }
}
