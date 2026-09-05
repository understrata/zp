const std = @import("std");
const e = @import("types.zig").Error;
const Dir = std.Io.Dir;
const linux = std.os.linux;

pub const PkgStat = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
};

pub fn GetPkgStatToInstall(pkg: []const u8, allocator: std.mem.Allocator) !PkgStat {
    const fd = linux.open("/var/zp/mirrors/zp.packages", linux.O{}, 0);
    if (linux.errno(fd) != .SUCCESS) {
        return error.OpenFailed;
    }

    const fd_i32: i32 = @intCast(fd);
    defer _ = linux.close(fd_i32);

    var statx: linux.Statx = undefined;
    const statx_result = linux.statx(fd_i32, "", linux.AT.EMPTY_PATH, linux.STATX{ .SIZE = true }, &statx);
    if (linux.errno(statx_result) != .SUCCESS) {
        return error.StatFailed;
    }

    const file_size: usize = @intCast(statx.size);
    if (file_size == 0) {
        return e.PkgNotFound;
    }

    const mmap_result = linux.mmap(null, file_size, linux.PROT{ .READ = true }, linux.MAP{ .TYPE = .PRIVATE }, fd_i32, 0);

    if (linux.errno(mmap_result) != .SUCCESS) {
        return error.MmapFailed;
    }

    const ptr: [*]const u8 = @ptrFromInt(mmap_result);

    defer _ = linux.munmap(ptr, file_size);

    const data = ptr[0..file_size];

    var reader = std.mem.tokenizeScalar(u8, data, '\n');
    while (reader.next()) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse return e.VersionNotFound;
        const url = tokens.next() orelse return e.NoURLFound;
        return .{ .name = try allocator.dupe(u8, name), .version = try allocator.dupe(u8, version), .url = try allocator.dupe(u8, url) };
    }
    return e.PkgNotFound;
}

pub fn getInstalledVersion(pkg: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    const fd = linux.open("/var/zp/install/packages.db", linux.O{}, 0);
    if (linux.errno(fd) != .SUCCESS) {
        return error.OpenFailed;
    }

    const fd_i32: i32 = @intCast(fd);
    defer _ = linux.close(fd_i32);

    var statx: linux.Statx = undefined;
    const statx_result = linux.statx(fd_i32, "", linux.AT.EMPTY_PATH, linux.STATX{ .SIZE = true }, &statx);
    if (linux.errno(statx_result) != .SUCCESS) {
        return error.StatFailed;
    }

    const file_size: usize = @intCast(statx.size);
    if (file_size == 0) {
        return e.PkgNotFound;
    }

    const mmap_result = linux.mmap(null, file_size, linux.PROT{ .READ = true }, linux.MAP{ .TYPE = .PRIVATE }, fd_i32, 0);

    if (linux.errno(mmap_result) != .SUCCESS) {
        return error.MmapFailed;
    }

    const ptr: [*]const u8 = @ptrFromInt(mmap_result);

    defer _ = linux.munmap(ptr, file_size);
    const data = ptr[0..file_size];

    var reader = std.mem.tokenizeScalar(u8, data, '\n');
    while (reader.next()) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse return null;
        return try allocator.dupe(u8, version);
    }
    return null;
}

pub fn GetInstalledPkgs(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const fd = linux.open("/var/zp/install/packages.db", linux.O{}, 0);
    if (linux.errno(fd) != .SUCCESS) {
        return error.OpenFailed;
    }

    const fd_i32: i32 = @intCast(fd);
    defer _ = linux.close(fd_i32);

    var statx: linux.Statx = undefined;
    const statx_result = linux.statx(fd_i32, "", linux.AT.EMPTY_PATH, linux.STATX{ .SIZE = true }, &statx);
    if (linux.errno(statx_result) != .SUCCESS) {
        return error.StatFailed;
    }

    const file_size: usize = @intCast(statx.size);
    if (file_size == 0) {
        return error.FileNotFound;
    }

    const mmap_result = linux.mmap(null, file_size, linux.PROT{ .READ = true }, linux.MAP{ .TYPE = .PRIVATE }, fd_i32, 0);

    if (linux.errno(mmap_result) != .SUCCESS) {
        return error.MmapFailed;
    }

    const ptr: [*]const u8 = @ptrFromInt(mmap_result);

    defer _ = linux.munmap(ptr, file_size);
    const data = ptr[0..file_size];

    var massive: std.ArrayList([]const u8) = .empty;
    var reader = std.mem.tokenizeScalar(u8, data, '\n');
    while (reader.next()) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        try massive.append(allocator, try allocator.dupe(u8, name));
    }
    return massive;
}
