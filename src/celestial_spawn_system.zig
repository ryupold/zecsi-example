const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const assets = zecsi.assets;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = assets.AssetLink;
const PointerDragger = zecsi.inputHandlers.PointerDragger;
const components = @import("components.zig");

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Rectangle = raylib.Rectangle;
const Texture2D = raylib.Texture2D;

/// spawns planets and other celestial objects
pub const CelestialSpawnSystem = struct {
    ecs: *ECS,
    camera: *CameraSystem,
    assets: *zecsi.baseSystems.AssetSystem,
    previousTouchPointCount: i32 = 0,
    mouse: PointerDragger = PointerDragger{ .button = .MOUSE_BUTTON_LEFT },
    rng: std.rand.Random = undefined,
    spawnTimer: zecsi.utils.Timer = .{ .repeat = true, .time = 0.1 },

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
            .camera = ecs.getSystem(CameraSystem).?,
            .assets = ecs.getSystem(zecsi.baseSystems.AssetSystem).?,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), dt: f32) !void {
        try self.spawnPlanets();
        try self.removePlanets();

        if (raylib.IsMouseButtonDown(.MOUSE_BUTTON_RIGHT) and self.spawnTimer.tick(dt)) {
            const min = self.camera.screenToWorld(.{ .x = 0, .y = 0 });
            const max = self.camera.screenToWorld(.{ .x = self.ecs.window.size.x, .y = self.ecs.window.size.y });

            const position = zecsi.utils.randomVector2(self.rng, min, max);

            try self.createPlanet(10, 10, position, .{});
        }
    }

    pub fn spawnCelestial(self: *@This(), appearance: components.Appearance, density: f32, radius: f32, position: Vector2, velocity: Vector2) !EntityID {
        std.debug.assert(density > 0);
        std.debug.assert(radius > 0);
        // var body = raylib.CreatePhysicsBodyCircle(position, radius, density);
        // body.velocity = velocity;
        const celestial = components.Celestial{
            // .body = body,
            .radius = radius,
            .density = density,
        };
        const body = components.PhysicsBody{
            .mass = celestial.mass(),
            .position = position,
            .velocity = velocity,
        };
        var entity = try self.ecs.create(.{ appearance, celestial, body });
        return entity.id;
    }

    fn spawnPlanets(self: *@This()) !void {
        self.mouse.update();

        if (self.mouse.dragLine()) |line| {
            const from = self.camera.screenToWorld(line.from);
            const fromI = from.int();
            const to = self.camera.screenToWorld(line.to);
            const toI = to.int();

            raylib.DrawLine(
                fromI.x,
                fromI.y,
                toI.x,
                toI.y,
                raylib.RED,
            );

            const velocity = line.delta().scale(1);
            const center = from.lerp(to, 0.5).int();
            var buf: [100]u8 = undefined;
            const veloText = try std.fmt.bufPrintZ(&buf, "{d:.2}", .{velocity.length()});

            raylib.DrawText(
                veloText,
                center.x,
                center.y,
                @floatToInt(i32, self.camera.screenLengthToWorld(12)),
                raylib.GREEN,
            );

            if (self.mouse.isReleased()) {
                const radius =
                    zecsi.utils.randomF32(self.rng, 5, 30);
                const density = zecsi.utils.randomF32(self.rng, 30, 30);
                try self.createPlanet(radius, density, from, velocity);
            }
        }
    }

    fn removePlanets(self: *@This()) !void {
        _ = self;
    }

    //--- Testing stuff ---------------------------------------------------------------------------
    fn createPlanet(self: *@This(), radius: f32, density: f32, position: raylib.Vector2, velocity: raylib.Vector2) !void {
        _ = try self.spawnCelestial(
            .{
                .name = "Earth",
                .bodyTex = (try self.assets.loadTexture("assets/images/celestials/earth.png")).asset.Texture2D,
            },
            density,
            radius,
            position,
            velocity,
        );
    }
};
