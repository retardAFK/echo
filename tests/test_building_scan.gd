extends GutTest
## Scanning a building with the playable monster (spec S-004, Q3, T-023).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
## In front of the building's west wall, looking at it (east).
const AIM_SPOT := Vector3(-24, 0, 13)
const INSIDE := Vector3(-11, 0.3, 13)
const OUTSIDE := Vector3(-24, 0.3, 20)

var _map: Node3D
var _avatar: MonsterAvatar
var _building: Building
var _markers: NoiseMarkers


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.set_physics_process(false)  # Driven by hand.
	_avatar.global_position = AIM_SPOT
	_avatar.look_at(INSIDE, Vector3.UP)
	_avatar.rotation.x = 0.0
	_building = _map.get_node("Building")
	_markers = _map.markers
	await wait_physics_frames(2)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func _hold(seconds: float, holding := true) -> void:
	var delta := 1.0 / Engine.physics_ticks_per_second
	for i in roundi(seconds / delta):
		_avatar.update_scan(delta, holding)
		await get_tree().physics_frame


func _faint_noise(at: Vector3) -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.BREATH, at, 0.5, self)


func test_building_volume() -> void:
	assert_true(_building.contains(INSIDE))
	assert_false(_building.contains(OUTSIDE))


func test_aims_at_the_building() -> void:
	assert_eq(_avatar.aim_building(), _building)
	_avatar.rotation.y += PI
	assert_null(_avatar.aim_building(), "nothing to scan behind")


func test_too_far_cannot_be_scanned() -> void:
	_avatar.global_position = INSIDE + Vector3(-_avatar.settings.scan_max_distance - 10, -0.3, 0)
	_avatar.look_at(INSIDE, Vector3.UP)
	await wait_physics_frames(1)
	assert_null(_avatar.aim_building())


func test_scan_reveals_faint_noises_inside_after_focus() -> void:
	await _hold(0.5)
	assert_true(_building.scanned)
	_faint_noise(INSIDE)
	assert_eq(_markers.get_active_count(), 0, "still concentrating")
	await _hold(0.7)
	_faint_noise(INSIDE)
	assert_eq(_markers.get_active_count(), 1, "heard through the scan")
	_faint_noise(OUTSIDE)
	assert_eq(_markers.get_active_count(), 1, "only noises from inside the building")


func test_releasing_ends_the_scan() -> void:
	watch_signals(_avatar)
	await _hold(1.5)
	assert_signal_emitted(_avatar, "scan_started")
	await _hold(0.1, false)
	assert_false(_avatar.scan.active)
	assert_false(_building.scanned)
	assert_signal_emitted(_avatar, "scan_ended")


func test_monster_stands_still_while_scanning() -> void:
	await _hold(0.2)
	var delta := 1.0 / Engine.physics_ticks_per_second
	var before := _avatar.global_position
	for i in 30:
		_avatar.update_scan(delta, true)
		_avatar.move(Vector2(0, 1), false, delta)
		await get_tree().physics_frame
	assert_almost_eq(_avatar.global_position.x, before.x, 0.01)
	assert_almost_eq(_avatar.global_position.z, before.z, 0.01)


func test_scan_reticle_is_pale() -> void:
	assert_eq(_map.find_children("*", "ScanReticle", false, false).size(), 1)
	assert_ne(_avatar.settings.scan_bar_color, NoiseBus.settings.noise_color)
