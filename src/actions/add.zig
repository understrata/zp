const std = @import("std");
const p = @import("../parser.zig");
const util = @import("../util.zig");

const build_script =
    \\set -e
    \\P=/usr
    \\D={s}
    \\mkdir -p "$D"
    \\if [ ! -x ./configure ] && {{ [ -f configure.ac ] || [ -f configure.in ]; }}; then
    \\  if [ -x ./autogen.sh ]; then ./autogen.sh; else autoreconf -fi; fi
    \\fi
    \\if [ -x ./configure ]; then
    \\  ./configure --prefix=$P
    \\  make -j$(nproc)
    \\  make install DESTDIR=$D
    \\elif [ -f CMakeLists.txt ]; then
    \\  cmake -B _zb -DCMAKE_INSTALL_PREFIX=$P
    \\  cmake --build _zb --parallel $(nproc)
    \\  DESTDIR=$D cmake --install _zb
    \\elif [ -f meson.build ]; then
    \\  meson setup _zb --prefix=$P
    \\  meson compile -C _zb
    \\  DESTDIR=$D meson install -C _zb
    \\elif [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
    \\  make -j$(nproc)
    \\  make install DESTDIR=$D
    \\else
    \\  echo "zp: Error: No cmake/make/meson files." >&2; exit 1
    \\fi
    \\cp -a /var/zp/pkg/. /
;

pub fn add(init: std.process.Init, pkg_name: []const u8) !void {
    var db_buf: [4096]u8 = undefined;
    const pkg = (try p.findPackage(init.io, p.mirrors_db_path, pkg_name, &db_buf)) orelse
        return error.PackageNotFound;

    const file_name = if (std.mem.lastIndexOfScalar(u8, pkg.url, '/')) |i| pkg.url[i + 1 ..] else pkg.url;
    const argv = [_][]const u8{ "curl", "-fSL", "-o", file_name, pkg.url };
    try util.runProcess(init.io, &argv, "/var/zp/install/");

    var dir_buf: [256]u8 = undefined;
    const build_dir = try std.fmt.bufPrint(&dir_buf, "/var/zp/build/{s}", .{pkg_name});
    try util.ensureDir(init.io, build_dir);

    var cmd_buf: [4096]u8 = undefined;
    const tar_cmd = try std.fmt.bufPrint(&cmd_buf, "tar -xf /var/zp/install/{s} -C {s} --strip-components=1", .{ file_name, build_dir });
    const argv_tar = [_][]const u8{ "sh", "-c", tar_cmd };
    try util.runProcess(init.io, &argv_tar, "/var/zp/install/");

    const build_cmd = try std.fmt.bufPrint(&cmd_buf, build_script, .{"/var/zp/pkg"});
    const argv_make = [_][]const u8{ "sh", "-c", build_cmd };
    try util.runProcess(init.io, &argv_make, build_dir);

    try p.writeFile(init.io, p.install_db_path, pkg_name, pkg.version);
}
