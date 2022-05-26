const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const raylib = zecsi.raylib;
// const PhysicsBody = raylib.PhysicsBodyData;
const Texture2D = raylib.Texture2D;

pub const Celestial = struct {
    // body: *PhysicsBody,
    density: f32,
    radius: f32,

    pub fn mass(self: @This()) f32 {
        return self.volume() * self.density;
    }

    pub fn area(self: @This()) f32 {
        return self.radius * self.radius * raylib.PI;
    }

    pub fn volume(self: @This()) f32 {
        return self.radius * self.radius * self.radius * raylib.PI;
    }
};

pub const Appearance = struct {
    name: [:0]const u8,
    bodyTex: Texture2D,
};

pub const PhysicsBody = struct {
    mass: f32,
    position: raylib.Vector2 = raylib.Vector2.zero(),
    velocity: raylib.Vector2 = raylib.Vector2.zero(),
    force: raylib.Vector2 = raylib.Vector2.zero(),
};
