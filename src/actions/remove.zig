const std = @import("std");
const util = @import("../util.zig");

pub fn remove(init: std.process.Init, pkg_name: []const u8) !void {
    if (std.mem.eql(u8, pkg_name, "none-package")) return;
    var cmd_buf: [4096]u8 = undefined;
    const remove_cmd = try std.fmt.bufPrint(&cmd_buf, "rm -rf /usr/bin/{s} /var/zp/pkg/{s} /usr/local/bin/{s} /usr/local/share/man/man1/{s}.1", .{ pkg_name, pkg_name, pkg_name, pkg_name });
    const argv = [_][]const u8{ "sh", "-c", remove_cmd };
    try util.runProcess(init.io, &argv, "/");
    std.debug.print("Successfully uninstalled pkg: {s}\n", .{pkg_name});
}
