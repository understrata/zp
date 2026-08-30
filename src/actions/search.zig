const std = @import("std");
const p = @import("../parser.zig");

pub fn search(init: std.process.Init, pkg_name: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    if (try p.hasPackage(init.io, p.mirrors_db_path, pkg_name, &buffer)) {
        std.debug.print("Found '{s}'\n", .{pkg_name});
    } else {
        std.debug.print("Not found '{s}'\n", .{pkg_name});
    }
}
