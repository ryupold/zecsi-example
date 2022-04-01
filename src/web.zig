const std = @import("std");
const Allocator = std.mem.Allocator;
const emsdk = @cImport({
    @cDefine("__EMSCRIPTEN__", "1");
    @cInclude("emscripten/emscripten.h");
});
const zecsi = @import("zecsi/main.zig");
const game = zecsi.game;
const log = zecsi.log;
const ZecsiAllocator = zecsi.ZecsiAllocator;

////special entry point for Emscripten build, called from src/emscripten/entry.c
pub export fn emsc_main() callconv(.C) c_int {
    return safeMain() catch |err| {
        log.err("ERROR: {?}", .{err});
        return 1;
    };
}

pub export fn emsc_set_window_size(width: usize, height: usize) callconv(.C) void {
    game.setWindowSize(width, height);
}

fn safeMain() !c_int {
    var zalloc = ZecsiAllocator{};
    const allocator = zalloc.allocator();
    try log.infoAlloc(allocator, "starting da game  ...", .{});

    try game.init(allocator, .{ .cwd = "" });
    try @import("game.zig").start(game.getECS());
    defer game.deinit();

    emsdk.emscripten_set_main_loop(gameLoop, 0, 1);
    log.info("after emscripten_set_main_loop", .{});

    log.info("CLEANUP", .{});
    if (zalloc.deinit()) {
        log.err("memory leaks detected!", .{});
        return 1;
    }
    return 0;
}

export fn gameLoop() callconv(.C) void {
    game.mainLoop() catch unreachable;
}
