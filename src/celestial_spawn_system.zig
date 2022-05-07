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
const MouseDragger = zecsi.inputHandlers.MouseDragger;
const components = @import("components.zig");

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Rectangle = raylib.Rectangle;
const Texture2D = raylib.Texture2D;

/// spawns planets and other celestial objects
pub const CelestialSpawnSystem = struct {
    ecs: *ECS,
    camera: *CameraSystem,
    previousTouchPointCount: i32 = 0,
    mouse: MouseDragger = MouseDragger{ .button = .MOUSE_BUTTON_LEFT },
    rng: std.rand.Random = undefined,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
            .camera = ecs.getSystem(CameraSystem).?,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        try self.spawnPlanets();
        try self.removePlanets();
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
                try self.createPlanet(self.rng, from, velocity);
            }
        }

        // const touchPointCount = raylib.GetTouchPointCount();
        // defer self.previousTouchPointCount = touchPointCount;

        // if (raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT) or (self.previousTouchPointCount == 1 and touchPointCount == 0)) {
        //     var random = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
        //     const rng = random.random();
        //     const position = if (raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT))
        //         raylib.GetMousePosition()
        //     else
        //         raylib.GetTouchPosition(0);

        //     const camera = self.ecs.getSystem(CameraSystem).?;
        //     const worldPos = camera.screenToWorld(position);

        //     try self.createPlanet(rng, worldPos, raylib.Vector2.randomInUnitCircle(rng).scale(zecsi.utils.randomF32(rng, 1, 10)));
        // }
    }

    fn removePlanets(self: *@This()) !void {
        _ = self;
    }

    //--- Testing stuff ---------------------------------------------------------------------------
    fn createPlanet(self: *@This(), rng: std.rand.Random, position: raylib.Vector2, velocity: raylib.Vector2) !void {
        _ = try self.spawnCelestial(
            .{ .name = "Earth", .bodyTex = raylib.LoadTexture("assets/images/celestials/earth.png") },
            zecsi.utils.randomF32(rng, 30, 30),
            zecsi.utils.randomF32(rng, 5, 30),
            position,
            velocity,
        );
    }
};
