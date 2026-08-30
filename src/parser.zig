const std = @import("std");

pub const mirrors_db_path = "/var/zp/mirrors/zp.packages";
pub const install_db_path = "/var/zp/install/packages.db";

pub const Package = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
};

pub fn findPackage(io: std.Io, path: []const u8, pkg: []const u8, buffer: []u8) !?Package {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse continue;
        const url = tokens.next() orelse continue;
        return .{ .name = name, .version = version, .url = url };
    }
    return null;
}

pub fn hasPackage(io: std.Io, path: []const u8, pkg: []const u8, buffer: []u8) !bool {
    return (try findPackage(io, path, pkg, buffer)) != null;
}

pub fn getInstalledVersion(io: std.Io, path: []const u8, pkg: []const u8, buffer: []u8) !?[]const u8 {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        return tokens.next();
    }
    return null;
}

pub fn getInstalledPkgs(io: std.Io, path: []const u8, buffer: []u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        try names.append(allocator, try allocator.dupe(u8, name));
    }
    return names;
}

pub fn writeFile(io: std.Io, path: []const u8, pkg: []const u8, version: []const u8) !void {
    try removePkgEntry(io, path, pkg);

    var buffer: [4096]u8 = undefined;
    const clean_version = std.mem.trim(u8, version, "\n\r ");
    const line = try std.fmt.bufPrint(&buffer, "{s} {s}\n", .{ pkg, clean_version });

    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => try cwd.createFile(io, path, .{}),
        else => return err,
    };
    defer file.close(io);

    const stat = try file.stat(io);
    try file.writePositionalAll(io, line, stat.size);
}

pub fn removePkgEntry(io: std.Io, path: []const u8, pkg: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch return;
    defer file.close(io);

    var tmp_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_path = try std.fmt.bufPrint(&tmp_path_buf, "{s}.tmp", .{path});

    const tmp_file = try cwd.createFile(io, tmp_path, .{});
    defer tmp_file.close(io);

    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    var write_buf: [4096]u8 = undefined;
    var writer = tmp_file.writer(io, &write_buf);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (std.mem.eql(u8, name, pkg)) continue;
        try writer.interface.writeAll(line);
        try writer.interface.writeByte('\n');
    }
    try writer.interface.flush();

    try cwd.rename(tmp_path, cwd, path, io);
}

const testing = std.testing;

fn tmpPath(buffer: []u8, tmp: *testing.TmpDir, name: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, name });
}

fn writeDb(io: std.Io, path: []const u8, content: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writePositionalAll(io, content, 0);
}

fn readDb(io: std.Io, path: []const u8, buffer: []u8) ![]const u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const len = try file.readPositionalAll(io, buffer, 0);
    return buffer[0..len];
}

test "findPackage returns the matching entry" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "zp.packages");
    try writeDb(io, path, "htop 3.2.1 https://example.com/htop-3.2.1.tar.gz\nvim 9.0.1 https://example.com/vim-9.0.1.tar.gz\n");

    var buffer: [4096]u8 = undefined;
    const htop = (try findPackage(io, path, "htop", &buffer)).?;
    try testing.expectEqualStrings("htop", htop.name);
    try testing.expectEqualStrings("3.2.1", htop.version);
    try testing.expectEqualStrings("https://example.com/htop-3.2.1.tar.gz", htop.url);

    const vim = (try findPackage(io, path, "vim", &buffer)).?;
    try testing.expectEqualStrings("9.0.1", vim.version);

    try testing.expect((try findPackage(io, path, "bash", &buffer)) == null);
}

test "findPackage skips malformed lines" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "zp.packages");
    try writeDb(io, path, "broken-no-fields\nhtop-no-url 1.0\nhtop 3.2.1 https://example.com/htop.tar.gz\n");

    var buffer: [4096]u8 = undefined;
    try testing.expect((try findPackage(io, path, "broken-no-fields", &buffer)) == null);
    try testing.expect((try findPackage(io, path, "htop-no-url", &buffer)) == null);
    try testing.expect((try findPackage(io, path, "htop", &buffer)) != null);
}

test "hasPackage" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "zp.packages");
    try writeDb(io, path, "htop 3.2.1 https://example.com/htop.tar.gz\n");

    var buffer: [4096]u8 = undefined;
    try testing.expect(try hasPackage(io, path, "htop", &buffer));
    try testing.expect(!(try hasPackage(io, path, "bash", &buffer)));
}

test "getInstalledVersion" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");
    try writeDb(io, path, "htop 3.2.1\nvim 9.0\n");

    var buffer: [4096]u8 = undefined;
    try testing.expectEqualStrings("3.2.1", (try getInstalledVersion(io, path, "htop", &buffer)).?);
    try testing.expect((try getInstalledVersion(io, path, "bash", &buffer)) == null);
    try testing.expect((try getInstalledVersion(io, path, "missing.db", &buffer)) == null);
}

test "getInstalledPkgs lists names in order" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");
    try writeDb(io, path, "htop 3.2.1\n\nvim 9.0\n");

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var buffer: [4096]u8 = undefined;
    const names = try getInstalledPkgs(io, path, &buffer, arena.allocator());
    try testing.expectEqual(@as(usize, 2), names.items.len);
    try testing.expectEqualStrings("htop", names.items[0]);
    try testing.expectEqualStrings("vim", names.items[1]);
}

test "writeFile replaces an existing entry" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");
    try writeDb(io, path, "vim 9.0\nhtop 1.0\n");

    try writeFile(io, path, "htop", "2.0");

    var read_buf: [256]u8 = undefined;
    try testing.expectEqualStrings("vim 9.0\nhtop 2.0\n", try readDb(io, path, &read_buf));
}

test "writeFile creates the database when missing" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");

    try writeFile(io, path, "htop", "3.2.1");

    var read_buf: [256]u8 = undefined;
    try testing.expectEqualStrings("htop 3.2.1\n", try readDb(io, path, &read_buf));
}

test "writeFile trims the version" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");

    try writeFile(io, path, "htop", "3.2.1 \n");

    var read_buf: [256]u8 = undefined;
    try testing.expectEqualStrings("htop 3.2.1\n", try readDb(io, path, &read_buf));
}

test "removePkgEntry removes only the matching entry" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "packages.db");
    try writeDb(io, path, "vim 9.0\nhtop 1.0\ncurl 8.0\n");

    try removePkgEntry(io, path, "htop");

    var read_buf: [256]u8 = undefined;
    try testing.expectEqualStrings("vim 9.0\ncurl 8.0\n", try readDb(io, path, &read_buf));
}

test "removePkgEntry tolerates a missing database" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [128]u8 = undefined;
    const path = try tmpPath(&path_buf, &tmp, "missing.db");

    try removePkgEntry(io, path, "htop");
}
