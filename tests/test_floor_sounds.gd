extends GutTest
## Footsteps on each floor, puddles, the monster's scrape (spec S-012, T-143).

const SURFACES: SurfaceMap = preload("res://game/maps/tilleuls/tilleuls_surfaces.tres")
const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const ORIGIN := Vector3(110, 0, 110)
const FloorBuilder := preload("res://tools/godot/floor_builder.gd")
const NOISE: NoiseSettings = preload("res://game/data/noise_settings.tres")


func _world(x: float, h: float, y: float) -> Vector3:
	return Vector3(x, h, y) - ORIGIN


func _kinds() -> Array:
	return Array(SURFACES.kinds)


func test_the_map_knows_every_floor() -> void:
	for kind: int in [
		FloorSurface.Kind.CONCRETE,
		FloorSurface.Kind.TILE,
		FloorSurface.Kind.WOOD,
		FloorSurface.Kind.PUDDLE,
	]:
		assert_has(_kinds(), kind, FloorSurface.NAMES[kind])
	assert_eq(SURFACES.ground_kind, FloorSurface.Kind.EARTH, "the dead lawn")


func test_paths_lawn_and_puddles() -> void:
	assert_eq(SURFACES.kind_at(_world(105, 0.3, 60)), FloorSurface.Kind.CONCRETE, "a path")
	assert_eq(SURFACES.kind_at(_world(80, 0.3, 62)), FloorSurface.Kind.EARTH, "the lawn")
	var puddles := 0
	for i in SURFACES.boxes.size():
		if SURFACES.kinds[i] == FloorSurface.Kind.PUDDLE:
			puddles += 1
			var box: AABB = SURFACES.boxes[i]
			var feet := box.get_center()
			feet.y = box.position.y + FloorBuilder.BELOW
			assert_eq(SURFACES.kind_at(feet), FloorSurface.Kind.PUDDLE, "feet in it")
			assert_eq(
				SURFACES.kind_at(feet + Vector3.UP * NOISE.emit_height), FloorSurface.Kind.PUDDLE
			)
	assert_gte(puddles, 15, "12 outdoors, the car park's")


func test_smallest_box_wins() -> void:
	var map := SurfaceMap.new()
	map.add(AABB(Vector3(-10, -1, -10), Vector3(20, 3, 20)), FloorSurface.Kind.CONCRETE)
	map.add(AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2)), FloorSurface.Kind.PUDDLE)
	map.sort()
	assert_eq(map.kind_at(Vector3.ZERO), FloorSurface.Kind.PUDDLE)
	assert_eq(map.kind_at(Vector3(5, 0, 5)), FloorSurface.Kind.CONCRETE)
	assert_eq(map.kind_at(Vector3(50, 0, 50)), FloorSurface.Kind.EARTH, "open ground")
	assert_eq(map.kind_at(Vector3(50, 9, 50)), FloorSurface.Kind.CONCRETE, "up high")


func test_rooms_have_their_floor_in_the_map() -> void:
	var map: Node = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var tree := get_tree()
	var kinds := {}
	for box: AABB in SURFACES.boxes:
		var feet := box.get_center()
		feet.y = box.position.y + FloorBuilder.BELOW
		kinds[FloorSurface.at(tree, feet)] = true
	for kind: int in [FloorSurface.Kind.TILE, FloorSurface.Kind.WOOD, FloorSurface.Kind.PUDDLE]:
		assert_true(kinds.has(kind), FloorSurface.NAMES[kind])
	assert_eq(FloorSurface.at(tree, _world(118, 6.1, 100)), FloorSurface.Kind.METAL, "fire escape")


func test_puddles_double_the_footsteps() -> void:
	var puddle := FloorSurface.Kind.PUDDLE
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.CROUCH, puddle), 2.0)
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.WALK, puddle), 8.0)
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.SPRINT, puddle), 20.0)
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.WALK), 4.0, "elsewhere")


func test_every_floor_has_four_steps_never_twice_the_same() -> void:
	var steps := FootstepSounds.new(7)
	for kind in FloorSurface.Kind.values():
		var last: AudioStream = null
		var seen := {}
		for i in 40:
			var stream := steps.step(kind)
			assert_not_null(stream)
			assert_ne(stream, last, "twice in a row")
			last = stream
			seen[stream] = true
		assert_eq(seen.size(), FootstepSounds.VARIANTS, FloorSurface.NAMES[kind])
		assert_not_null(SoundSpace.muffled_stream(last), "muffled version")
	assert_ne(steps.monster_step(), steps.step(FloorSurface.Kind.CONCRETE))


func test_the_monster_is_heard_scraping_even_online() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var ears: PlayerEars = player.find_children("*", "PlayerEars", true, false)[0]
	var hunted := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3(0, 0.3, -2), 4.0)
	var stream: AudioStream = ears.call("_stream_for", hunted)
	assert_true(stream.resource_path.contains("step_"), stream.resource_path)
	assert_false(stream.resource_path.contains("monster"))
	var copy := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3(0, 0.3, -2), 3.0, null, true)
	assert_true(copy.by_monster, "a client's copy keeps who made it")
	stream = ears.call("_stream_for", copy)
	assert_true(stream.resource_path.contains("monster_step"), stream.resource_path)
	var message := NetGame.noise_message(copy, player, false)
	assert_eq(message[4], true, "the room's message says it")


func test_one_hears_ones_own_steps_softly() -> void:
	var audio := AudioSettings.new()
	var walk := SoundMath.self_db(4.0, 4.0, audio)
	assert_almost_eq(walk, audio.self_walk_db, 0.01)
	assert_lt(SoundMath.self_db(1.0, 4.0, audio), walk, "crouched: quieter")
	assert_gt(SoundMath.self_db(14.0, 4.0, audio), walk, "running: louder")
	assert_gt(SoundMath.self_db(8.0, 4.0, audio), walk, "a puddle: louder")
	assert_lte(SoundMath.self_db(20.0, 4.0, audio), audio.self_max_db)
