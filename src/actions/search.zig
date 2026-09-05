const std = @import("std");
const p = @import("../parser.zig");

pub fn search(init: std.process.Init, pkg_item: []const u8) !void {
    const find = try p.GetPkgStatToInstall(pkg_item, init.arena.allocator());
    if (find.name.len != 0) {
        std.debug.print("Find '{s}':\n  Version: {s}\n  URL: {s}\n", .{ find.name, find.version, find.url });
    } else std.debug.print("No find '{s}'\n", .{pkg_item});
}
