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
    _debugEntityCount: usize = 0,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        var enities = self.ecs.query(.{ components.Celestial, components.PhysicsBody, components.Appearance });
        self._debugEntityCount = 0;
        while (enities.next()) |entity| {
            self._debugEntityCount += 1;
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
                    if (body.force.length2() > 1) body.position.add(body.force.scale(1 / body.force.length2())) else body.position.add(body.force.normalize().scale(body.force.length2() * 100)),
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

    pub fn ui(self: *@This(), _: f32) !void {
        var texBuf: [4096]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&texBuf, "{d} celestials", .{self._debugEntityCount});
        raylib.DrawText(text, @floatToInt(i32, self.ecs.window.size.x - 150), @floatToInt(i32, self.ecs.window.size.y - 30), 20, raylib.GREEN);

        // var buf : [4096]u8 = undefined;
        // const text = try std.fmt.bufPrintZ(&buf, "", .{});
        if (raylib.GuiButton(.{ .x = 20, .y = self.ecs.window.size.y - 50, .width = 70, .height = 30 }, if (!self._drawDebugArrows) "[ ] debug" else "[x] debug")) {
            self._drawDebugArrows = !self._drawDebugArrows;
            var gravitySystem = self.ecs.getSystem(zecsi.baseSystems.GridPlacementSystem).?;
            gravitySystem.isGridVisible = self._drawDebugArrows;
        }
    }
};
