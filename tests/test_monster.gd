extends GutTest
## Monster scene, test building and patrol in the greybox (spec S-003, T-015).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const BUILDING_PREFIX := "Building"
const WALLS_LAYER := 1 << 1
const MONSTER_LAYER := 1 << 3
## Simulated time to let the monster walk, in physics frames.
const WALK_FRAMES := 180

var _map: Node3D
var _monster: Monster


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_monster = _map.get_node("Monster")


func test_monster_settings_are_shared_resource() -> void:
	assert_not_null(_monster.settings)
	assert_eq(_monster.settings.resource_path, "res://game/data/monster_settings.tres")


func test_monster_is_on_its_own_layer() -> void:
	assert_eq(_monster.collision_layer, MONSTER_LAYER)


func test_patrol_route_has_four_points() -> void:
	assert_eq(_monster.get_patrol_points().size(), 4)


func test_starts_on_patrol_at_prowl_pace() -> void:
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)
	assert_eq(_monster.brain.get_pace(), MonsterBrain.Pace.PROWL)
	var start := _monster.get_patrol_points()[_monster.start_index]
	assert_eq(_monster.brain.target, start)


func test_building_walls_block_sound() -> void:
	var count := 0
	for block in _map.get_node("Blocks").get_children():
		if block.name.begins_with(BUILDING_PREFIX):
			count += 1
			assert_eq(block.collision_layer, WALLS_LAYER, "%s on walls layer" % block.name)
	assert_gt(count, 8, "the test building exists")


func test_navigation_mesh_is_baked() -> void:
	var region: NavigationRegion3D = _map.get_node("NavigationRegion3D")
	assert_gt(region.navigation_mesh.get_polygon_count(), 0, "run tools/godot/bake_navmesh.gd")


func test_speed_follows_pace() -> void:
	var s := _monster.settings
	assert_eq(MonsterBrain.speed_for(MonsterBrain.Pace.PROWL, s), s.prowl_speed)
	assert_eq(MonsterBrain.speed_for(MonsterBrain.Pace.WALK, s), s.walk_speed)
	assert_eq(MonsterBrain.speed_for(MonsterBrain.Pace.RUN, s), s.run_speed)


func test_walks_towards_first_patrol_point() -> void:
	var target := _monster.brain.target
	var before := _flat_distance(_monster.global_position, target)
	await wait_physics_frames(WALK_FRAMES)
	var after := _flat_distance(_monster.global_position, target)
	var expected := _monster.settings.prowl_speed * WALK_FRAMES / Engine.physics_ticks_per_second
	assert_lt(after, before - expected * 0.5, "moved at least half the prowl distance")
	assert_lt(_monster.velocity.length(), _monster.settings.prowl_speed + 0.1, "never faster")


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
