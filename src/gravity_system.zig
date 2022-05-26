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

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Texture2D = raylib.Texture2D;
const components = @import("components.zig");
const Celestial = components.Celestial;

/// applies gravity mechanics to all celestials
pub const GravitySystem = struct {
    /// gravitational constant
    pub const G: f32 = 0.03;
    ecs: *ECS,

    pub fn init(ecs: *ECS) !@This() {
        // defer {
        //     raylib.InitPhysics();
        //     raylib.SetPhysicsGravity(0, 0);
        // }

        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {
        // raylib.ClosePhysics();
    }

    pub fn update(self: *@This(), _: f32) !void {
        // raylib.UpdatePhysics();

        var enities = self.ecs.query(.{Celestial});
        while (enities.next()) |entity| {
            var celestial = entity.getData(self.ecs, Celestial).?;
            var body = entity.getData(self.ecs, components.PhysicsBody).?;
            const mass = celestial.mass();
            var otherEnities = self.ecs.query(.{Celestial});
            while (otherEnities.next()) |other| {
                if (entity.id == other.id) continue;
                var otherBody = other.getData(self.ecs, components.PhysicsBody) orelse continue;
                var otherCelestial = other.getData(self.ecs, Celestial).?;

                //calculate gravity force to other celestial
                const delta = body.position.sub(otherBody.position);

                if (delta.x != 0 and delta.y != 0) {
                    const force = newtonStyle(mass, otherBody.mass, delta);

                    //apply it toward this celestial
                    // raylib.PhysicsAddForce(otherCelestial.body, force);
                    otherBody.force.addSet(force);
                }

                //=== Collision =================
                if (body.mass > otherBody.mass) {
                    const collide = raylib.CheckCollisionCircles(body.position, celestial.radius, otherBody.position, otherCelestial.radius);
                    if (collide) {
                        celestial.radius += celestial.radius * (otherCelestial.mass() / celestial.mass());
                        //TODO: what about density?
                        body.mass = celestial.mass();
                        _ = try self.ecs.destroy(other);

                        body.velocity = body.velocity.scale(1 - (otherBody.mass / body.mass)).add(otherBody.velocity.scale(otherBody.mass / body.mass));
                    }
                }
            }
        }
    }

    fn newtonStyle(m1: f32, m2: f32, delta: Vector2) Vector2 {
        const force = delta.normalize().scale(G * (m1 * m2) / delta.length2());
        return force;
    }

    fn newton2D(m1: f32, m2: f32, delta: Vector2) Vector2 {
        const force = delta.normalize().scale(2 * G * (m1 * m2) / delta.length());
        return force;
    }
};
