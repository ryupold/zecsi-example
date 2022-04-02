const std = @import("std");
const zecsi = @import("zecsi/main.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const r = zecsi.raylib;
const grid = zecsi.baseSystems;
const camera = zecsi.baseSystems;
const GridPosition = grid.GridPosition;
const Vector2 = grid.Vector2;
const GridPlacementSystem = grid.GridPlacementSystem;
const assets = zecsi.assets;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = assets.AssetLink;
const TextureAtlas = assets.TextureAtlas;
const AnimatedTextureAtlas = assets.AnimatedTextureAtlas;
const randomF32 = zecsi.utils.randomF32;

pub const TreeStateType = std.meta.Tag(TreeState);
pub const TreeState = union(enum) {
    Seed: struct { timeToSprout: f32 },
    Sapling: struct { timeToGrow: f32 },
    Young: struct { timeToGrow: f32 },
    Mature: struct { sizeFactor: f32 = 1 },
    Dead: struct { sizeFactor: f32 = 1 },
};

var random = std.rand.DefaultPrng.init(0);
const rng = random.random();

pub const Tree = struct {
    id: usize,
    state: TreeState = .{ .Seed = .{ .timeToSprout = 2 } },
    age: f32 = 0,
    timeInState: f32 = 0,

    offsetInCell: Vector2 = Vector2.zero(),
    drawSize: f32 = GridPlacementSystem.cellSize,

    pub fn changeState(self: *@This(), state: TreeState) void {
        self.state = state;
        self.timeInState = 0;
    }

    pub fn tick(self: *@This(), dt: f32) void {
        self.age += dt;
        self.timeInState += dt;

        switch (self.state) {
            .Seed => |seed| {
                if (self.timeInState >= seed.timeToSprout) {
                    self.changeState(.{ .Sapling = .{ .timeToGrow = randomF32(rng, 1, 10) } });
                }
            },
            .Sapling => |sapling| {
                if (self.timeInState >= sapling.timeToGrow) {
                    self.changeState(.{ .Young = .{ .timeToGrow = randomF32(rng, 1, 12) } });
                }
            },
            .Young => |young| {
                if (self.timeInState >= young.timeToGrow) {
                    self.changeState(.{ .Mature = .{ .sizeFactor = randomF32(rng, 1, 1.2) } });
                }
            },
            .Mature => {},
            .Dead => {},
        }
    }
};

const Fire = struct {
    burnTime: f32 = 0,
    tex: AnimatedTextureAtlas,

    pub fn tick(self: *@This(), dt: f32) void {
        self.burnTime += dt;
        self.tex.tick(dt);
    }
};

const Burnable = struct {
    timeNearFire: f32 = 0,
    startBurningThreshold: f32 = 5,
};

const Health = struct {
    hp: f32 = 1,
};

const TreeGridCell = std.ArrayList(EntityID);
const TreeGrid = std.AutoHashMap(GridPosition, TreeGridCell);
const TreeConfig = struct {
    treesPerCell: u32,
    treesPerClick: u32,
    drawOffsetX: f32,
    drawOffsetY: f32,
};

pub const TreeSystem = struct {
    const maxTreesPerCell: usize = 4;

    ecs: *ECS,
    treeMap: TreeGrid,
    treeTex: *AssetLink,
    fireTex: *AssetLink,
    rng: std.rand.Random,
    timer: Timer = .{ .time = 2, .repeat = true },
    treeDrawCache: std.ArrayList(TreeDrawInfo),
    treeConfig: *AssetLink,
    treeCounter: i32 = 0,
    treesDead: i32 = 0,
    _singleFingerTouchedFrames: usize = 0,

    pub fn init(ecs: *ECS) !@This() {
        var ass: *AssetSystem = if (ecs.getSystem(AssetSystem)) |ass|
            ass
        else
            @panic("no asset system registered");

        var system = @This(){
            .ecs = ecs,
            .rng = random.random(),
            .treeMap = TreeGrid.init(ecs.allocator),
            .treeDrawCache = std.ArrayList(TreeDrawInfo).init(ecs.allocator),
            .treeTex = try ass.loadTextureAtlas("assets/images/plants/tree_1.png", 6, 1),
            .fireTex = try ass.loadTextureAtlas("assets/images/effects/fire_1.png", 3, 1),
            .treeConfig = try ass.loadJson("assets/data/plants/tree_planting.json"),
        };

        return system;
    }

    pub fn deinit(self: *@This()) void {
        var it = self.treeMap.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        self.treeMap.deinit();
        self.treeDrawCache.deinit();

        if (self.ecs.getSystem(AssetSystem)) |_| {
            // ass.unload(self.fireTex);
            // ass.unload(self.treeTex);
            // ass.unload(self.treeConfig);
        } else {
            std.log.err("no asset system registered", .{});
            return;
        }
    }

    pub fn update(self: *@This(), dt: f32) !void {
        //so we don't draw while zooming
        if (r.GetTouchPointCount() == 1) {
            self._singleFingerTouchedFrames += 1;
        } else {
            self._singleFingerTouchedFrames = 0;
        }

        if (r.GetTouchPointCount() == 1) {
            if (self._singleFingerTouchedFrames > 40) try self.createTreeAt(r.GetTouchPosition(0));
        } else if (r.IsMouseButtonDown(0)) {
            try self.createTreeAt(r.GetMousePosition());
        } else if (r.IsMouseButtonDown(1)) {
            try self.burnTreeAt(r.GetMousePosition());
        } else if (r.GetTouchPointCount() == 2) {
            try self.burnTreeAt(r.GetTouchPosition(0).lerp(r.GetTouchPosition(1), 0.5));
        }

        self.treeDrawCache.clearRetainingCapacity();
        var it = self.ecs.query(.{ GridPosition, Tree, Health });
        while (it.next()) |entity| {
            var gridPos = entity.getData(self.ecs, GridPosition).?;
            var tree = entity.getData(self.ecs, Tree).?;
            var health = entity.getData(self.ecs, Health).?;

            tree.tick(dt);

            //--- fire -----------------------------------
            if (entity.getData(self.ecs, Fire)) |fire| {
                fire.tick(dt);
                health.hp -= dt / 10;

                if (self.treeMap.get(gridPos.*)) |treesInMyCell| {
                    for (treesInMyCell.items) |neigbourTree| {
                        //a fire in my cell
                        if (self.ecs.getOnePtr(neigbourTree, Burnable)) |burnable| {
                            burnable.timeNearFire += dt * rng.float(f32);
                            // break;
                        }
                    }
                }
                // neigbours:
                for (gridPos.neigbours()) |neigbour| {
                    if (self.treeMap.get(neigbour)) |trees| {
                        for (trees.items) |neigbourTree| {
                            //a fire in a neighbouring cell
                            if (self.ecs.getOnePtr(neigbourTree, Burnable)) |burnable| {
                                burnable.timeNearFire += dt * 0.1 * rng.float(f32);
                                // break :neigbours;
                            }
                        }
                    }
                }
            } else if (entity.getData(self.ecs, Burnable)) |burnable| {
                if (burnable.timeNearFire > burnable.startBurningThreshold) {
                    if (!entity.has(Fire)) try self.startFire(entity.id, gridPos.*);
                }
            }
            //--------------------------------------------

            if (health.hp <= 0 and tree.state != .Dead) {
                tree.changeState(.{ .Dead = .{
                    .sizeFactor = randomF32(rng, 0.7, 1.2),
                } });
                self.treesDead += 1;
                try self.ecs.removeAll(entity, Fire);
            }
            try self.treeDrawCache.append(.{
                .id = entity.id,
                .pos = gridPos.*,
                .tree = tree.*,
                .health = health.*,
            });
        }
        sortTreesForDrawing(&self.treeDrawCache);

        for (self.treeDrawCache.items) |x| {
            self.drawTree(
                grid.toWorldPosition(x.pos),
                x.tree,
                x.health,
                self.ecs.getOnePtr(x.id, Fire),
            );
        }

        if (self.timer.tick(dt)) {}

        try self.drawTreeConfig();
    }

    fn drawTreeConfig(self: *@This()) !void {
        var config: TreeConfig = try self.treeConfig.asset.Json.as(TreeConfig);
        var buf: [8096]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&buf, "trees planted: {d}\nalive trees: {d}\ntrees per cell: {d}", .{
            self.treeCounter,
            self.treeCounter - self.treesDead,
            config.treesPerCell,
        });
        const camSystem: *camera.CameraSystem = self.ecs.getSystem(camera.CameraSystem).?;
        const textPos = camSystem.screenToWorld(Vector2{
            .x = self.ecs.window.size.x - config.drawOffsetX,
            .y = self.ecs.window.size.y - config.drawOffsetY,
        }).int();

        r.DrawText(
            text,
            textPos.x,
            textPos.y,
            @floatToInt(i32, 20 * 1.0 / camSystem.zoom()),
            r.GREEN,
        );
    }

    fn burnTreeAt(self: *@This(), pos: Vector2) !void {
        const camSystem: *camera.CameraSystem = self.ecs.getSystem(camera.CameraSystem).?;
        const camFix = camSystem.screenToWorld(pos);
        const gridPos: GridPosition = grid.toGridPosition(camFix);

        if (self.treeMap.getPtr(gridPos)) |treeList| {
            if (treeList.items.len == 0) return;

            const entity: EntityID = treeList.items[
                self.rng.intRangeLessThan(
                    usize,
                    0,
                    treeList.items.len,
                )
            ];
            try self.startFire(entity, gridPos);
        }
    }

    fn startFire(self: *@This(), tree: EntityID, atPosition: GridPosition) !void {
        const removedBurnable = self.ecs.removeComponent(tree, Burnable) catch false;
        if (removedBurnable and !self.ecs.has(tree, Fire)) {
            _ = try self.ecs.add(tree, Fire{ .tex = AnimatedTextureAtlas.init(
                self.fireTex,
                0.5,
                true,
            ) });

            log.debug("tree #{d} is on fire!", .{tree});
        }
        if (self.ecs.getOnePtr(tree, Tree)) |t| {
            if (t.state == .Dead) {
                if (self.treeMap.getPtr(atPosition)) |treeList| {
                    for (treeList.items) |tt, i| {
                        if (tt == tree) {
                            _ = treeList.swapRemove(i);
                            _ = self.ecs.destroy(tree) catch {
                                log.debug("could not remove tree #{d}", .{tree});
                            };
                            self.treeCounter -= 1;
                            self.treesDead -= 1;
                            break;
                        }
                    }
                }
            }
        }
    }

    fn createTreeAt(self: *@This(), pos: Vector2) !void {
        const camSystem: *camera.CameraSystem = self.ecs.getSystem(camera.CameraSystem).?;
        const camFix = camSystem.screenToWorld(pos);

        const gridPos: GridPosition = grid.toGridPosition(camFix);

        var list: *TreeGridCell =
            (try self.treeMap.getOrPutValue(gridPos, TreeGridCell.init(self.ecs.allocator))).value_ptr;

        if (list.items.len < maxTreesPerCell) {
            var e = try self.ecs.createWithCapacity(6);
            var tree = Tree{
                .id = e.id,
                .offsetInCell = Vector2.randomInUnitCircle(self.rng).clampX(-0.9, 0.9).scale(
                    GridPlacementSystem.cellSize / 2,
                ),
            };
            //optical fix so that the tree is drawn inside the cell
            if (tree.offsetInCell.y > 0) tree.offsetInCell.y *= -1.0;

            _ = try self.ecs.add(e, gridPos);
            _ = try self.ecs.add(e, tree);
            _ = try self.ecs.add(e, Health{ .hp = 1 });
            _ = try self.ecs.add(e, Burnable{ .startBurningThreshold = randomF32(self.rng, 1, 8) });
            try list.append(e.id);
            self.treeCounter += 1;
        }
    }

    //=== DRAW ====================================================================================

    fn drawTree(self: *@This(), pos: Vector2, tree: Tree, health: Health, fire: ?*Fire) void {
        const index: u32 = switch (tree.state) {
            .Seed => 0,
            .Sapling => 1,
            .Young => 2,
            .Mature => if (health.hp > 0.2) @as(u32, 3) else @as(u32, 4),
            .Dead => 5,
        };
        const treePos = pos.add(tree.offsetInCell);
        var drawSize = Vector2{ .x = tree.drawSize, .y = tree.drawSize };
        if (tree.state == .Mature)
            drawSize = drawSize.scale(tree.state.Mature.sizeFactor);
        self.treeTex.asset.TextureAtlas.drawEasy(index, treePos, drawSize);

        if (fire) |f| {
            f.tex.atlas.asset.TextureAtlas.drawEasy(f.tex.index, treePos, drawSize.scale(
                0.5 + f.burnTime / 10.0,
            ));
        }
    }

    const TreeDrawInfo = struct { id: EntityID, pos: GridPosition, tree: Tree, health: Health };
    fn sortTreesForDrawing(trees: *std.ArrayList(TreeDrawInfo)) void {
        std.sort.sort(TreeDrawInfo, trees.items, {}, compareTreesForDrawing);
    }

    fn compareTreesForDrawing(_: void, t1: TreeDrawInfo, t2: TreeDrawInfo) bool {
        return t1.pos.y < t2.pos.y or (t1.pos.y == t2.pos.y and t1.tree.offsetInCell.y < t2.tree.offsetInCell.y);
    }
};
