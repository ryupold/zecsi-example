const std = @import("std");
const zecsi = @import("zecsi");
const ECS = zecsi.ECS;
const base = zecsi.baseSystems;
const raylib = zecsi.raylib;
const components = @import("components.zig");
const CelestialSpawnSystem = @import("celestial_spawn_system.zig").CelestialSpawnSystem;
const CelestialSystem = @import("celestial_system.zig").CelestialSystem;
const CameraSystem = base.CameraSystem;
const PhysicsSystem = @import("physics_system.zig").PhysicsSystem;

pub fn start(ecs: *ECS) !void {
    const allocator = ecs.allocator;
    _ = allocator; //<-- use this allocator

    // these are some usefull base systems
    _ = try ecs.registerSystem(base.AssetSystem);
    _ = try ecs.registerSystem(base.GridPlacementSystem);
    var cameraSystem = try ecs.registerSystem(CameraSystem);
    cameraSystem.initMouseDrag(base.CameraMouseDrag{ .button = .MOUSE_BUTTON_RIGHT });
    cameraSystem.initMouseZoomScroll(base.CameraScrollZoom{ .factor = 0.1 });
    cameraSystem.initTouchZoomAndDrag(base.TwoFingerZoomAndDrag{ .factor = 0.5 });

    //register your systems here
    _ = try ecs.registerSystem(@import("gravity_system.zig").GravitySystem);
    _ = try ecs.registerSystem(CelestialSystem);
    _ = try ecs.registerSystem(PhysicsSystem);
    _ = try ecs.registerSystem(CelestialSpawnSystem);
}
