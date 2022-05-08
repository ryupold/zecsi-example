const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const drawArrow = zecsi.utils.drawArrow;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const assets = zecsi.assets;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = assets.AssetLink;

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Rectangle = raylib.Rectangle;

const components = @import("components.zig");

/// keeps track of all celestials
/// if two celestials collide it combines their mass and appearance
pub const CelestialSystem = struct {
    ecs: *ECS,

    _drawDebugArrows: bool = @import("builtin").mode == .Debug,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        var enities = self.ecs.query(.{ components.Celestial, components.PhysicsBody, components.Appearance });
        while (enities.next()) |entity| {
            const celestial = entity.getData(self.ecs, components.Celestial).?;
            const body = entity.getData(self.ecs, components.PhysicsBody).?;
            const appearance = entity.getData(self.ecs, components.Appearance).?;

            const src: Rectangle = .{
                .x = 0,
                .y = 0,
                .width = @intToFloat(f32, appearance.bodyTex.width),
                .height = @intToFloat(f32, appearance.bodyTex.height),
            };
            const dest: Rectangle = .{
                .x = body.position.x,
                .y = body.position.y,
                .width = celestial.radius * 2,
                .height = celestial.radius * 2,
            };
            raylib.DrawTexturePro(appearance.bodyTex, src, dest, .{ .x = celestial.radius, .y = celestial.radius }, 0, raylib.WHITE);

            if (self._drawDebugArrows) {
                drawArrow(
                    body.position,
                    body.position.add(body.force),
                    .{ .color = raylib.BLUE.set(.{ .a = 127 }) },
                );
                drawArrow(
                    body.position,
                    body.position.add(body.velocity),
                    .{ .color = raylib.GREEN.set(.{ .a = 127 }) },
                );
            }
        }

        if (raylib.IsKeyReleased(.KEY_G)) {
            self._drawDebugArrows = !self._drawDebugArrows;
        }
    }
};
