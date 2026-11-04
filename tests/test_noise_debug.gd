extends GutTest
## Noise debug view and test probes in the greybox (spec S-002, T-011).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
# Where the player stands next to the test wall, on the open side.
const NEAR_TEST_WALL := Vector3(0.0, 0.3, 13.6)
const START := Vector3(0.0, 0.3, 8.0)

var _map: Node3D
var _debug: NoiseDebug
var _settings: NoiseSettings


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_debug = _map.get_node("NoiseDebug")
	_settings = NoiseBus.settings
	# The monster breathes every second: keep it still so only test noises count.
	_map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(2)


func _probe(probe_name: String) -> NoiseProbe:
	return _map.get_node("Probes/%s" % probe_name)


func _emit(position: Vector3, noise_range: float) -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, position, noise_range)


func test_probes_hidden_until_f4() -> void:
	assert_false(_probe("ProbeOpen").visible)
	_debug.set_enabled(true)
	assert_true(_probe("ProbeOpen").visible)
	_debug.set_enabled(false)
	assert_false(_probe("ProbeOpen").visible)


func test_f4_key_toggles_debug() -> void:
	var press := InputEventAction.new()
	press.action = "toggle_noise_debug"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(2)
	assert_true(_debug.enabled)


func test_rings_only_when_enabled() -> void:
	_emit(START, _settings.walk_range)
	assert_eq(_debug.get_ring_count(), 0)
	_debug.set_enabled(true)
	_emit(START, _settings.walk_range)
	assert_eq(_debug.get_ring_count(), 1)


func test_rings_fade_out() -> void:
	_debug.set_enabled(true)
	_emit(START, _settings.walk_range)
	await wait_seconds(_settings.debug_ring_lifetime + 0.2)
	assert_eq(_debug.get_ring_count(), 0)


func test_open_probe_hears_sprint_not_walk() -> void:
	# Spec S-002: a probe 10 m away in open space.
	var probe := _probe("ProbeOpen")
	_emit(START, _settings.walk_range)
	assert_false(probe.is_lit())
	_emit(START, _settings.sprint_range)
	assert_true(probe.is_lit())


func test_probe_behind_wall_hears_sprint_not_walk() -> void:
	# Spec S-002: a probe about 6 m away behind a wall.
	var probe := _probe("ProbeBehindWall")
	assert_eq(NoiseBus.walls_between(NEAR_TEST_WALL, probe.global_position), 1)
	_emit(NEAR_TEST_WALL, _settings.walk_range)
	assert_false(probe.is_lit())
	_emit(NEAR_TEST_WALL, _settings.sprint_range)
	assert_true(probe.is_lit())
