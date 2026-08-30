const std = @import("std");
const p = @import("../parser.zig");
const a = @import("add.zig");

pub fn updatePkg(init: std.process.Init, pkg_name: []const u8) !void {
    var install_buf: [4096]u8 = undefined;
    var mirrors_buf: [4096]u8 = undefined;

    const installed_ver = try p.getInstalledVersion(init.io, p.install_db_path, pkg_name, &install_buf) orelse {
        std.debug.print("Package '{s}' is not installed\n", .{pkg_name});
        return;
    };

    const pkg = (try p.findPackage(init.io, p.mirrors_db_path, pkg_name, &mirrors_buf)) orelse
        return error.PackageNotFound;

    if (std.mem.eql(u8, installed_ver, pkg.version)) {
        std.debug.print("{s} is up to date ({s})\n", .{ pkg_name, installed_ver });
    } else {
        std.debug.print("Updating {s}: {s} → {s}\n", .{ pkg_name, installed_ver, pkg.version });
        try a.add(init, pkg_name);
    }
}

pub fn updateAll(init: std.process.Init) !void {
    var buffer: [8096]u8 = undefined;
    const names = p.getInstalledPkgs(init.io, p.install_db_path, &buffer, init.arena.allocator()) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("No installed packages found\n", .{});
            return;
        }
        return err;
    };
    for (names.items) |pkg_name| {
        try updatePkg(init, pkg_name);
    }
}
