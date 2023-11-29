const std = @import("std");

var rng: ?std.rand.DefaultPrng = null;

pub fn random() std.rand.Random {
    if (rng == null) {
        rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    }
    return rng.?.random();
}
