extends GutTest
## Noises shown to the playable monster with their distance (spec S-004, Q2, T-022).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const OPEN_SPOT := Vector3(0, 0, -16)

var _map: Node3D
var _avatar: MonsterAvatar
var _markers: NoiseMarkers


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.process_mode = Node.PROCESS_MODE_DISABLED  # No own breath in the counts.
	_avatar.global_position = OPEN_SPOT
	_markers = _map.markers
	await wait_physics_frames(2)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func _noise_at(offset: Vector3, noise_range: float) -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, OPEN_SPOT + offset, noise_range, self)


func test_distance_text_and_fade() -> void:
	assert_eq(NoiseMarkers.distance_text(10.6), "11 m")
	assert_eq(NoiseMarkers.fade_alpha(0.0, 3.0), 1.0)
	assert_almost_eq(NoiseMarkers.fade_alpha(1.5, 3.0), 0.5, 0.001)
	assert_eq(NoiseMarkers.fade_alpha(4.0, 3.0), 0.0)


func test_heard_noise_shows_its_distance() -> void:
	_noise_at(Vector3(0, 0, 3), 14.0)
	assert_eq(_markers.get_active_count(), 1)
	var marker: NoiseMarker = _markers.get_child(0)
	var expected := NoiseMarkers.distance_text(
		_avatar.get_ear_position().distance_to(OPEN_SPOT + Vector3(0, 0, 3))
	)
	assert_eq(marker.get_node("Label").text, expected)
	assert_eq(marker.color, NoiseBus.settings.noise_color, "orange is the noise colour")


func test_noise_out_of_range_is_not_shown() -> void:
	_noise_at(Vector3(0, 0, 10), 4.0)
	assert_eq(_markers.get_active_count(), 0)


func test_own_noise_is_not_shown() -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, OPEN_SPOT, 12.0, _avatar)
	assert_eq(_markers.get_active_count(), 0)


func test_marker_fades_out() -> void:
	_noise_at(Vector3(0, 0, -3), 14.0)
	await wait_seconds(_avatar.settings.marker_fade_time + 0.2)
	assert_eq(_markers.get_active_count(), 0)
	assert_false(_markers.get_child(0).visible)


func test_markers_are_reused() -> void:
	for i in _avatar.settings.marker_count + 3:
		_noise_at(Vector3(0, 0, 2), 14.0)
	var rings := _markers.get_children().filter(func(n: Node) -> bool: return n is NoiseMarker)
	assert_eq(rings.size(), _avatar.settings.marker_count)
