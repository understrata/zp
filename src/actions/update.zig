const std = @import("std");
const p = @import("../parser.zig");
const a = @import("add.zig");
const linux = std.os.linux;

pub fn updatePkg(init: std.process.Init, pkg_name: []const u8, allocator: std.mem.Allocator) !void {
    const installed_ver = try p.getInstalledVersion(pkg_name, allocator);

    if (installed_ver) |iv| {
        defer allocator.free(iv);
        const pkg = try p.GetPkgStatToInstall(pkg_name, allocator);

        defer {
            allocator.free(pkg.name);
            allocator.free(pkg.version);
            allocator.free(pkg.url);
        }

        if (!std.mem.eql(u8, iv, pkg.version)) {
            std.log.info("Updating {s}: {s} → {s}\n", .{ pkg_name, iv, pkg.version });
            try a.add(init, pkg_name, allocator);
        } else {
            std.debug.print("{s} is up to date ({s})\n", .{ pkg_name, iv });
        }
    } else {
        std.debug.print("Package '{s}' is not installed\n", .{pkg_name});
    }
}

pub fn updateAll(init: std.process.Init) !void {
    const fd = linux.open("/var/zp/install/packages.db", linux.O{}, 0);
    if (linux.errno(fd) != .SUCCESS) {
        return error.OpenFailed;
    }

    var buf: [65536]u8 = undefined;
    const fd_i32: i32 = @intCast(fd);
    defer _ = linux.close(fd_i32);
    const read = linux.read(fd_i32, &buf, buf.len);

    if (linux.errno(read) != .SUCCESS) {
        return error.ReadFailed;
    }

    const content = buf[0..read];

    var reader = std.mem.tokenizeScalar(u8, content, '\n');
    while (reader.next()) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        try updatePkg(init, name, init.arena.allocator());
    }
}

// update == upgrade
