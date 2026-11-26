extends GutTest
## The Versus arena of the cité and the falls (spec S-024, Q24, Q29, Q34,
## T-376): pieces and starts inside the barriers, stairs up to the social
## centre's roof, and what a fall costs. Every door open and everything
## reachable (S-025, T-401).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")
## Plan points of the cité (x east, y south) in world coordinates.
const TOWER_HALL := Vector3(-6, 0.3, -10)
const CENTRE_ROOF := Vector3(50, 4.3, -38)
## Foot of the south stairs up to the social centre's roof, rising west.
const ROOF_STAIRS_FOOT := Vector3(67.5, 0.1, -25.3)

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT
	Engine.time_scale = 1.0
	Input.action_release("move_forward")


func _arena() -> VersusArena:
	return SETTINGS.arenas[0]


func test_falls_cost_what_the_spec_says() -> void:
	var s := VersusSettings.new()
	assert_eq(FallRules.hunted_damage(s, 3.0, 3), 0, "under 4 m: nothing")
	assert_eq(FallRules.hunted_damage(s, 4.3, 3), 1, "a roof of the social centre")
	assert_eq(FallRules.hunted_damage(s, 9.0, 3), 2)
	assert_eq(FallRules.hunted_damage(s, 12.0, 3), 3, "past 10 m: down")
	assert_eq(FallRules.after_roll(s, 1, 4.3), 0, "a roll saves a point")
	assert_eq(FallRules.after_roll(s, 3, 12.0), 3, "not from a deadly fall")
	assert_eq(FallRules.boss_damage(s, 5.0, 1200.0), 0.0)
	assert_almost_eq(FallRules.boss_damage(s, 9.0, 1200.0), 60.0, 0.01, "5 % of its health")
	assert_false(FallRules.is_loud(s, 2.0))


func test_the_fall_watch_measures_from_the_highest_point() -> void:
	var watch := FallWatch.new()
	assert_eq(watch.update(true, 4.3), 0.0)
	assert_eq(watch.update(false, 4.3), 0.0)
	assert_eq(watch.update(false, 4.5), 0.0)
	assert_eq(watch.update(false, 1.0), 0.0)
	assert_almost_eq(watch.update(true, 0.0), 4.5, 0.001)
	assert_eq(watch.update(true, 0.0), 0.0, "once")


func test_the_arena_starts_everyone_inside_and_far_apart() -> void:
	var arena := _arena()
	assert_eq(arena.map_path, MAP_SCENE.resource_path)
	assert_not_null(arena.navigation_mesh)
	assert_gt(arena.hunted_spawns.size(), 3, "4 hunted at most")
	for point in arena.hunted_spawns:
		assert_true(arena.contains(point))
		assert_between(point.distance_to(arena.boss_spawn), 50.0, 75.0, "about 60 m (Q29)")
	assert_true(arena.contains(arena.boss_spawn))
	for piece in arena.pieces:
		var centre := piece.transform.origin
		var inside := arena.bounds.grow(1.0).has_point(Vector2(centre.x, centre.z))
		assert_true(inside, "piece at %s in the barriers" % centre)


func test_a_versus_in_the_cite_takes_place_in_the_arena() -> void:
	GameSession.role = GameSession.Role.HUNTED
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	var versus := map.get_node("VersusMode") as VersusMode
	assert_eq(versus.arena, _arena())
	var builder := map.get_node("VersusArena")
	assert_lte(
		builder.find_children("*", "MeshInstance3D", false, false).size(), 4, "4 draw calls at most"
	)
	assert_almost_eq(map.player.global_position.x, _arena().hunted_spawn(0).x, 0.5)
	assert_null(map.get_node_or_null("GameLoop"), "no fuses in the Versus")
	var region: NavigationRegion3D = map.get_node("NavigationRegion3D")
	assert_eq(region.navigation_mesh, _arena().navigation_mesh)
	var nav := map.get_world_3d().navigation_map
	var start := _arena().hunted_spawn(0)
	await wait_until(  # The navigation map takes the new mesh.
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav, start)
			return Vector2(closest.x, closest.z).distance_to(Vector2(start.x, start.z)) < 0.1,
		5
	)
	var to_roof := NavigationServer3D.map_get_path(nav, start, CENTRE_ROOF, true)
	assert_almost_eq(to_roof[-1].distance_to(CENTRE_ROOF), 0.0, 1.0, "stairs to the roof")
	var to_hall := NavigationServer3D.map_get_path(nav, start, TOWER_HALL, true)
	assert_almost_eq(to_hall[-1].distance_to(TOWER_HALL), 0.0, 1.0, "the tower is open (S-025)")
	var targets: Array[Vector3] = [_arena().boss_spawn]
	targets.append_array(_arena().chest_spots)
	for i in _arena().hunted_spawns.size():
		targets.append(_arena().hunted_spawn(i))
	for target in targets:
		var path := NavigationServer3D.map_get_path(nav, start, target, true)
		assert_almost_eq(path[-1].distance_to(target), 0.0, 1.5, "reachable: %s" % target)
	for node in map.get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		assert_true(door.is_open and door.held_open, "%s open for good" % door.name)
		assert_false(door.can_use(map.player), "nobody closes it")


func test_the_player_walks_up_to_the_roof() -> void:
	GameSession.role = GameSession.Role.HUNTED
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	var player := map.player
	player.global_position = ROOF_STAIRS_FOOT
	player.set_look(PI / 2.0, 0.0)  # West.
	Input.action_press("move_forward")
	await wait_seconds(4.0)
	Input.action_release("move_forward")
	assert_gt(player.global_position.y, 4.0, "on the roof")
