const zecsi = @import("zecsi/main.zig");
const ECS = zecsi.ECS;
const base = zecsi.baseSystems;
const raylib = zecsi.raylib;

const example = @import("tree_system.zig");

pub fn start(ecs: *ECS) !void {
    const allocator = ecs.allocator;
    _ = allocator;//<-- use this allocator

    // these are some usefull base systems
    _ = try ecs.registerSystem(base.AssetSystem);
    _ = try ecs.registerSystem(base.GridPlacementSystem);
    var cameraSystem = try ecs.registerSystem(base.CameraSystem);
    cameraSystem.initMouseDrag(base.CameraMouseDrag{ .button = 2 });
    cameraSystem.initMouseZoomScroll(base.CameraScrollZoom{ .factor = 0.1 });
    cameraSystem.initTouchZoomAndDrag(base.TwoFingerZoomAndDrag{ .factor = 0.5 });
    
    //register your systems here
    _ = try ecs.registerSystem(example.TreeSystem);
    
}
