const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const drawArrow = zecsi.utils.drawArrow;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;

const raylib = zecsi.raylib;
const Vector2 = raylib.Vector2;
const Texture2D = raylib.Texture2D;
const components = @import("components.zig");

/// move physic bodies by force
pub const PhysicsSystem = struct {
    ecs: *ECS,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){
            .ecs = ecs,
        };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), dt: f32) !void {
        var enities = self.ecs.query(.{components.PhysicsBody});
        while (enities.next()) |entity| {
            var body = entity.getData(self.ecs, components.PhysicsBody).?;
            if (body.force.x != 0 and body.force.y != 0) {
                const force = body.force.scale(1 / body.mass);
                drawArrow(
                    body.position,
                    body.position.add(force),
                    .{ .color = raylib.BLUE.set(.{ .a = 127 }) },
                );

                body.velocity.addSet(force.scale(dt));
                body.force.setZero();
            }
            drawArrow(body.position, body.position.add(body.velocity), .{ .color = raylib.GREEN.set(.{ .a = 127 }) });

            body.position.addSet(body.velocity.scale(dt));
        }
    }
};
