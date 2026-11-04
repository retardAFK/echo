extends GutTest
## Monster noises, placeholder sounds and debug (spec S-003, T-018).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const OPEN_SPOT := Vector3(0, 0, -16)

var _map: Node3D
var _monster: Monster
var _player: Player
var _ears: PlayerEars
var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_monster = _map.get_node("Monster")
	_player = _map.get_node("Player")
	_ears = _player.get_node("PlayerEars")
	_heard.clear()
	NoiseBus.noise_emitted.connect(_record)
	await wait_physics_frames(2)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	if event.source == _monster:
		_heard.append(event)


func _monster_steps() -> Array[NoiseEvent]:
	return _heard.filter(func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.FOOTSTEP)


func test_noise_ranges_follow_d009() -> void:
	var s := _monster.settings
	assert_eq(MonsterBrain.noise_range_for(MonsterBrain.Pace.PROWL, s), 0.0)
	assert_eq(MonsterBrain.noise_range_for(MonsterBrain.Pace.WALK, s), 3.0)
	assert_eq(MonsterBrain.noise_range_for(MonsterBrain.Pace.RUN, s), 12.0)
	assert_eq(s.breath_range, 2.0)


func test_prowling_makes_no_footstep_noise() -> void:
	await wait_seconds(2.0)
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)
	assert_eq(_monster_steps().size(), 0, "silent while prowling")


func test_breathes_every_interval() -> void:
	await wait_seconds(_monster.settings.breath_interval * 2.5)
	var breaths := _heard.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.BREATH
	)
	assert_eq(breaths.size(), 2)
	assert_eq(breaths[0].noise_range, _monster.settings.breath_range)


func test_walking_to_a_noise_makes_footsteps() -> void:
	_monster.global_position = OPEN_SPOT
	_monster.brain.hear(OPEN_SPOT + Vector3(10, 0, 0))
	await wait_seconds(1.5)
	var steps := _monster_steps()
	assert_gt(steps.size(), 0)
	assert_eq(steps[0].noise_range, _monster.settings.walk_range)


func test_player_hears_only_within_range() -> void:
	_player.global_position = OPEN_SPOT
	_monster.process_mode = Node.PROCESS_MODE_DISABLED
	var far := OPEN_SPOT + Vector3(8, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, far, _monster.settings.walk_range, _monster)
	assert_eq(_ears.heard_count, 0, "a walk 8 m away is silent")
	var near := OPEN_SPOT + Vector3(1.5, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, _monster.settings.walk_range, _monster)
	assert_eq(_ears.heard_count, 1)


func test_player_does_not_hear_itself() -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _player.global_position, 14.0, _player)
	assert_eq(_ears.heard_count, 0)


func test_placeholder_sounds_are_generated() -> void:
	var step := PlaceholderSounds.step()
	var breath := PlaceholderSounds.breath()
	var bytes_per_second := PlaceholderSounds.MIX_RATE * 2
	assert_almost_eq(
		float(step.data.size()) / bytes_per_second, PlaceholderSounds.STEP_LENGTH, 0.01
	)
	assert_almost_eq(
		float(breath.data.size()) / bytes_per_second, PlaceholderSounds.BREATH_LENGTH, 0.01
	)


func test_debug_overlay_shows_monster() -> void:
	var overlay: DebugOverlay = _map.get_node("DebugOverlay")
	overlay.refresh()
	var text: String = overlay.get_node("Label").text
	assert_string_contains(text, "MONSTER PATROL")
	assert_string_contains(text, "caught 0")


func test_vision_cone_follows_f4() -> void:
	var cone: Node3D = _monster.get_node("VisionCone")
	assert_false(cone.visible)
	_map.get_node("NoiseDebug").set_enabled(true)
	assert_true(cone.visible)
