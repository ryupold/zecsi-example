const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const Allocator = std.mem.Allocator;
const game = zecsi.game;
const log = zecsi.log;
const r = zecsi.raylib;
const ZecsiAllocator = zecsi.ZecsiAllocator;

const updateWindowSizeEveryNthFrame = 30;

fn compError(comptime fmt: []const u8, args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}

pub fn main() anyerror!void {
    var zalloc = ZecsiAllocator{};
    //init allocator
    const allocator = zalloc.allocator();
    defer {
        log.info("free memory...", .{});
        if (zalloc.deinit()) {
            log.err("memory leaks detected!", .{});
        }
    }

    const exePath = try std.fs.selfExePathAlloc(allocator);
    const cwd = std.fs.path.dirname(exePath).?;
    defer allocator.free(exePath);
    log.info("current path: {s}", .{cwd});

    //remove to prevent resizing of window
    r.SetConfigFlags(.{ .FLAG_WINDOW_RESIZABLE = true });
    var frame: usize = 0;
    var lastWindowSize: struct { w: i32 = 0, h: i32 = 0 } = .{};

    // game start/stop
    log.info("starting game...", .{});
    try game.init(allocator, .{ .gameName = "zecsi-example", .cwd = cwd, .initialWindowSize = .{
        .width = 800,
        .height = 800,
    } });

    try @import("game.zig").start(game.getECS());

    defer {
        log.info("stopping game...", .{});
        game.deinit();
    }

    r.SetTargetFPS(60);

    while (!r.WindowShouldClose()) {
        if (frame % updateWindowSizeEveryNthFrame == 0) {
            const newW = r.GetScreenWidth();
            const newH = r.GetScreenHeight();
            if (newW != lastWindowSize.w or newH != lastWindowSize.h) {
                log.debug("changed screen size {d}x{x}", .{ newW, newH });
                game.setWindowSize(newW, newH);
                lastWindowSize.w = newW;
                lastWindowSize.h = newH;
            }
        }
        frame += 1;
        try game.mainLoop();
        r.DrawFPS(10, 10);
    }
}
