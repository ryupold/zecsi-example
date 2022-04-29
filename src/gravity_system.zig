const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const assets = zecsi.assets;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = assets.AssetLink;
const celestialSys = @import("celestial_system.zig");
const CelestialSystem = celestialSys.CelestialSystem;
const Celestial = celestialSys.Celestial;

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Texture2D = raylib.Texture2D;

/// applies gravity mechanics to all celestials
pub const GravitySystem = struct {
    /// gravitational constant
    pub const G: f32 = 0.001;
    ecs: *ECS,

    pub fn init(ecs: *ECS) !@This() {
        defer {
            raylib.InitPhysics();
            raylib.SetPhysicsGravity(0, 0);
        }

        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {
        raylib.ClosePhysics();
    }

    pub fn update(self: *@This(), _: f32) !void {
        raylib.UpdatePhysics();

        var enities = self.ecs.query(.{Celestial});
        while (enities.next()) |entity| {
            var celestial = entity.getData(self.ecs, Celestial).?;
            var otherEnities = self.ecs.query(.{Celestial});
            while (otherEnities.next()) |other| {
                if (entity.id == other.id) continue;
                var otherCelestial = other.getData(self.ecs, Celestial).?;
                if (!otherCelestial.body.enabled) continue; // cannot move

                //calculate gravity force to other celestial
                const delta = celestial.body.position.sub(otherCelestial.body.position);
                const force = delta.normalize().scale(G * (celestial.body.mass * otherCelestial.body.mass) / delta.length2());
                //apply it toward this celestial
                raylib.PhysicsAddForce(otherCelestial.body, force);
            }
        }
    }
};
