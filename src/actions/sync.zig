const std = @import("std");
const util = @import("../util.zig");

pub fn sync(init: std.process.Init) !void {
    const argv = [_][]const u8{ "sh", "-c", "/var/zp/mirrors/gen.sh" };
    try util.runProcess(init.io, &argv, ".");
}
