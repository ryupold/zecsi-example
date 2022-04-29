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

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Rectangle = raylib.Rectangle;
const Texture2D = raylib.Texture2D;
const PhysicsBody = raylib.PhysicsBodyData;

/// keeps track of all celestials
/// if two celestials collide it combines their mass and appearance
pub const CelestialSystem = struct {
    ecs: *ECS,
    previousTouchPointCount: i32 = 0,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        try self.ReactToInputs();

        var enities = self.ecs.query(.{ Celestial, Appearance });
        while (enities.next()) |entity| {
            const celestial = entity.getData(self.ecs, Celestial).?;
            const appearance = entity.getData(self.ecs, Appearance).?;

            const src: Rectangle = .{
                .x = 0,
                .y = 0,
                .width = @intToFloat(f32, appearance.bodyTex.width),
                .height = @intToFloat(f32, appearance.bodyTex.height),
            };
            const dest: Rectangle = .{
                .x = celestial.body.position.x,
                .y = celestial.body.position.y,
                .width = celestial.radius * 2,
                .height = celestial.radius * 2,
            };
            raylib.DrawTexturePro(appearance.bodyTex, src, dest, .{ .x = celestial.radius, .y = celestial.radius }, 0, raylib.WHITE);
        }
    }

    pub fn spawnCelestial(self: *@This(), appearance: Appearance, density: f32, radius: f32, position: Vector2, velocity: Vector2) !EntityID {
        var body = raylib.CreatePhysicsBodyCircle(position, radius, density);
        body.velocity = velocity;
        const celestial = Celestial{
            .body = body,
            .radius = radius,
        };
        var entity = try self.ecs.create(.{ appearance, celestial });
        return entity.id;
    }

    fn ReactToInputs(self: *@This()) !void {
        const touchPointCount = raylib.GetTouchPointCount();
        defer self.previousTouchPointCount = touchPointCount;

        if (raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT) or (self.previousTouchPointCount == 1 and touchPointCount == 0)) {
            var random = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
            const rng = random.random();
            const position = if (raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT))
                raylib.GetMousePosition()
            else
                raylib.GetTouchPosition(0);

            const camera = self.ecs.getSystem(CameraSystem).?;
            const worldPos = camera.screenToWorld(position);

            try self.createPlanet(rng, worldPos, raylib.Vector2.randomInUnitCircle(rng).scale(zecsi.utils.randomF32(rng, 1, 10)));
        }
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

pub const Celestial = struct {
    body: *PhysicsBody,
    radius: f32,
};

pub const Appearance = struct {
    name: [:0]const u8,
    bodyTex: Texture2D,
};
