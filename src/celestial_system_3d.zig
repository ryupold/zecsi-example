const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
// const drawArrow3D = zecsi.utils.drawArrow3D;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const assets = zecsi.assets;
const CameraSystem3D = zecsi.baseSystems.CameraSystem3D;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = assets.AssetLink;

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Rectangle = raylib.Rectangle;

const components = @import("components.zig");

/// keeps track of all celestials
/// if two celestials collide it combines their mass and appearance
pub const CelestialSystem3D = struct {
    ecs: *ECS,
    cameraSystem: *CameraSystem3D,

    _drawDebugArrows: bool = false,
    _debugEntityCount: usize = 0,
    _updateTime: i128 = 0,

    pub fn init(ecs: *ECS) !@This() {
        var s = @This(){
            .ecs = ecs,
            .cameraSystem = ecs.getSystem(CameraSystem3D).?,
        };

        s.cameraSystem.setCamPos(.{ .x = 0, .y = 1000, .z = 0 });
        s.cameraSystem.setCamMode(.CAMERA_FREE);

        return s;
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        const start = std.time.milliTimestamp();
        defer self._updateTime = std.time.milliTimestamp() - start;

        const cam = self.ecs.getPtr(raylib.Camera3D, self.cameraSystem.camRef).?.*;

        var enities = self.ecs.query(.{ components.Celestial, components.PhysicsBody, components.Appearance });
        self._debugEntityCount = 0;
        while (enities.next()) |entity| {
            self._debugEntityCount += 1;
            const celestial = entity.getData(self.ecs, components.Celestial).?;
            const body = entity.getData(self.ecs, components.PhysicsBody).?;
            const appearance = entity.getData(self.ecs, components.Appearance).?;

            // raylib.DrawSphereEx(
            //     body.position.x0z(),
            //     celestial.radius,
            //     5,
            //     5,
            //     if (body.mass >= 1000) raylib.YELLOW else raylib.GREEN,
            // );

            raylib.DrawBillboard(
                cam,
                appearance.bodyTex,
                body.position.x0z(),
                celestial.radius,
                if (body.mass >= 1000) raylib.YELLOW else raylib.GREEN,
            );

            if (self._drawDebugArrows) {
                // drawArrow3D(
                //     body.position.x0z(),
                //     body.position.add(body.velocity).x0z(),
                //     .{ .color = raylib.GREEN.set(.{ .a = 127 }) },
                // );
            }
        }

        if (raylib.IsKeyReleased(.KEY_G)) {
            self._drawDebugArrows = !self._drawDebugArrows;
        }
    }

    pub fn ui(self: *@This(), _: f32) !void {
        var texBuf: [4096]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&texBuf, "{d} celestials\nupdate {d}ms", .{ self._debugEntityCount, self._updateTime });
        raylib.DrawText(
            text,
            @floatToInt(i32, self.ecs.window.size.x - 150),
            @floatToInt(i32, self.ecs.window.size.y - 60),
            20,
            raylib.GREEN,
        );

        if (raylib.GuiButton(.{ .x = 20, .y = self.ecs.window.size.y - 50, .width = 70, .height = 30 }, if (!self._drawDebugArrows) "[ ] debug" else "[x] debug")) {
            self._drawDebugArrows = !self._drawDebugArrows;
            // var gravitySystem = self.ecs.getSystem(zecsi.baseSystems.GridPlacementSystem).?;
            // gravitySystem.isGridVisible = self._drawDebugArrows;
        }
    }
};
