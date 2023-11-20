const std = @import("std");
const zecsi = @import("zecsi");
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

var random = std.rand.DefaultPrng.init(1337);

/// spawns planets and other celestial objects
pub const CelestialSpawnSystem = struct {
    ecs: *ECS,
    camera: *CameraSystem,
    assets: *zecsi.baseSystems.AssetSystem,
    previousTouchPointCount: i32 = 0,
    mouse: PointerDragger = PointerDragger{ .button = .MOUSE_BUTTON_LEFT },
    rng: std.rand.Random = random.random(),
    spawnTimer: zecsi.utils.Timer = .{ .repeat = true, .time = 0.1 },
    spawnPlanetCount: usize = 1000,
    spawnMinRange: f32 = 1000,
    spawnMaxRange: f32 = 5000,
    spawnSun: bool = true,

    pub fn init(ecs: *ECS) !@This() {
        var spawner = @This(){
            .ecs = ecs,
            .camera = ecs.getSystem(CameraSystem).?,
            .assets = ecs.getSystem(zecsi.baseSystems.AssetSystem).?,
        };

        try spawner.resetCelestials();

        return spawner;
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        try self.spawnPlanets();
        try self.removePlanets();

        // if (raylib.IsMouseButtonDown(.MOUSE_BUTTON_RIGHT) and self.spawnTimer.tick(dt)) {
        //     const min = self.camera.screenToWorld(.{ .x = 0, .y = 0 });
        //     const max = self.camera.screenToWorld(.{ .x = self.ecs.window.size.x, .y = self.ecs.window.size.y });

        //     const position = zecsi.utils.randomVector2(self.rng, min, max);

        //     try self.createPlanet(10, 30, position, .{});
        // }
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
        var entity = try self.ecs.create();
        try self.ecs.put(entity, appearance);
        try self.ecs.put(entity, celestial);
        try self.ecs.put(entity, body);
        return entity;
    }

    fn spawnPlanets(self: *@This()) !void {
        self.mouse.update();

        // if (self.mouse.dragLine()) |line| {
        //     const from = self.camera.screenToWorld(line.from);
        //     const fromI = from.int();
        //     const to = self.camera.screenToWorld(line.to);
        //     const toI = to.int();

        //     raylib.DrawLine(
        //         fromI.x,
        //         fromI.y,
        //         toI.x,
        //         toI.y,
        //         raylib.RED,
        //     );

        //     const velocity = line.delta().scale(1);
        //     const center = from.lerp(to, 0.5).int();
        //     var buf: [100]u8 = undefined;
        //     const veloText = try std.fmt.bufPrintZ(&buf, "{d:.2}", .{velocity.length()});

        //     raylib.DrawText(
        //         veloText,
        //         center.x,
        //         center.y,
        //         @as(i32, @intFromFloat(self.camera.screenLengthToWorld(12))),
        //         raylib.GREEN,
        //     );

        //     if (self.mouse.isReleased()) {
        //         const radius =
        //             zecsi.utils.randomF32(self.rng, 5, 30);
        //         const density = zecsi.utils.randomF32(self.rng, 30, 30);
        //         try self.createPlanet(radius, density, from, velocity);
        //     }
        // }
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

    fn createSun(self: *@This(), position: raylib.Vector2) !void {
        _ = try self.spawnCelestial(
            .{ .name = "Sun", .bodyTex = raylib.LoadTexture("assets/images/celestials/sun.png") },
            1000,
            50,
            position,
            .{ .x = 0, .y = 0 },
        );
    }

    pub fn resetCelestials(self: *@This()) !void {
        var cam = self.ecs.getPtr(self.camera.camera, raylib.Camera2D).?;
        cam.target = .{};

        var enities = self.ecs.query(.{.{ "celestial", components.Celestial }});
        var toDelete = std.ArrayList(zecsi.EntityID).init(self.ecs.allocator);
        defer toDelete.deinit();

        while (enities.next()) |entry| {
            try toDelete.append(entry.entity);
        }

        for (toDelete.items) |d| {
            _ = try self.ecs.destroy(d);
        }

        if (self.spawnSun) {
            try self.createSun(Vector2.zero());
        }

        var i: usize = 0;
        while (i < self.spawnPlanetCount) : (i += 1) {
            const pos = Vector2.randomOnUnitCircle(self.rng).scale(zecsi.utils.randomF32(self.rng, self.spawnMinRange, self.spawnMaxRange));
            const force = pos.scale(-1).rotate(raylib.PI / 2).normalize().scale(zecsi.utils.randomF32(self.rng, 50, 150));
            // Vector2.randomInUnitCircle(self.rng).scale(zecsi.utils.randomF32(self.rng, 300, 400));

            try self.createPlanet(zecsi.utils.randomF32(self.rng, 5, 15), 100, pos, force);
        }
    }

    pub fn ui(self: *@This(), _: f32) !void {
        // self.spawnSun = raylib.uiCheckBox("spawn sun", .{ .x = 20, .y = self.ecs.window.size.y - 200, .width = 20, .height = 20 }, self.spawnSun);

        // const maxCount: f32 = 1000;
        // var buf: [4096]u8 = undefined;
        // var sliderRect = raylib.Rectangle{ .x = 20, .y = self.ecs.window.size.y - 150, .width = 150, .height = 30 };
        // const sliderValue = raylib.GuiSlider(sliderRect, "1", "1000", @intToFloat(f32, self.spawnPlanetCount), 1, @floatToInt(i32, maxCount));
        // self.spawnPlanetCount = @floatToInt(usize, sliderValue);
        // sliderRect.x += (sliderRect.width * sliderValue / maxCount);
        // raylib.GuiLabel(sliderRect, try std.fmt.bufPrintZ(&buf, "{d}", .{self.spawnPlanetCount}));

        if (zecsi.ui.uiButton("reset", .{ .x = 20, .y = self.ecs.window.size.y - 100, .width = 70, .height = 30 }, .{})) {
            try self.resetCelestials();
        }
    }
};
