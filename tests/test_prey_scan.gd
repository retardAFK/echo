extends GutTest
## Panting, scan warning, catching the prey and debug (spec S-004, Q4 to Q6, T-026).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const INSIDE := Vector3(-11, 0, 13)
const AIM_SPOT := Vector3(-24, 0, 13)

var _map: Node3D
var _avatar: MonsterAvatar
var _prey: Prey
var _building: Building
var _breaths: Array[NoiseEvent] = []


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.set_physics_process(false)  # Driven by hand.
	_avatar.global_position = AIM_SPOT
	_avatar.look_at(INSIDE, Vector3.UP)
	_prey = _map.prey
	_prey.settings = _prey.settings.duplicate()
	_building = _map.get_node("Building")
	_breaths.clear()
	NoiseBus.noise_emitted.connect(_record)
	await wait_physics_frames(2)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	if event.source == _prey and event.type == NoiseEvent.Type.BREATH:
		_breaths.append(event)


## The prey ran and now hides inside the building, out of breath.
func _hide_breathless_inside() -> void:
	_prey.global_position = INSIDE
	_prey.brain.update(0.1, true, AIM_SPOT, false, false)
	_prey.brain.give_up()
	assert_eq(_prey.get_state(), PreyBrain.State.HIDE)
	assert_true(_prey.brain.is_breathless())


func test_rested_prey_makes_no_breath() -> void:
	await wait_seconds(_prey.settings.breath_interval * 2.5)
	assert_eq(_breaths.size(), 0)


func test_breathless_prey_pants_faintly() -> void:
	_hide_breathless_inside()
	await wait_seconds(_prey.settings.breath_interval * 2.5)
	assert_eq(_breaths.size(), 2)
	assert_eq(_breaths[0].noise_range, _prey.settings.breath_range)


func test_scan_reveals_the_panting_of_a_hidden_prey() -> void:
	_hide_breathless_inside()
	var delta := 1.0 / Engine.physics_ticks_per_second
	for i in roundi(2.5 / delta):
		_avatar.update_scan(delta, true)
		await get_tree().physics_frame
	assert_true(_avatar.scan.is_listening())
	assert_gt(_breaths.size(), 0)
	assert_gt(_map.markers.get_active_count(), 0, "the scan shows the panting")


func test_noticing_the_scan_freezes_the_prey() -> void:
	_prey.settings.scan_notice_chance = 1.0
	_prey.global_position = INSIDE
	_building.scanned = true
	await wait_physics_frames(2)
	assert_true(_prey.is_warned())
	assert_eq(_prey.get_state(), PreyBrain.State.FREEZE)
	_building.scanned = false
	await wait_physics_frames(2)
	assert_false(_prey.is_warned())
	assert_eq(_prey.get_state(), PreyBrain.State.WANDER)


func test_a_prey_that_looks_away_misses_the_scan() -> void:
	_prey.settings.scan_notice_chance = 0.0
	_prey.global_position = INSIDE
	_building.scanned = true
	await wait_physics_frames(2)
	assert_false(_prey.is_warned())


func test_a_prey_outside_ignores_the_scan() -> void:
	_prey.settings.scan_notice_chance = 1.0
	_prey.global_position = Vector3(5, 0, 8)
	_building.scanned = true
	await wait_physics_frames(2)
	assert_false(_prey.is_warned())


func test_touching_the_prey_catches_it() -> void:
	_prey.process_mode = Node.PROCESS_MODE_DISABLED
	_prey.global_position = Vector3(5, 0, 8)
	_avatar.global_position = Vector3(5.8, 0, 8)
	await wait_physics_frames(2)
	assert_eq(_avatar.catch_count, 1)
	var caught: CaughtScreen = _map.get_node("CaughtScreen")
	assert_true(caught.visible)
	assert_eq(caught.get_node("Label").text, "HUD_PREY_CAUGHT")
	assert_eq(tr("HUD_PREY_CAUGHT"), "Attrapée")
	assert_gt(_prey.global_position.distance_to(_avatar.global_position), 10.0, "respawned far")
	assert_eq(_prey.get_state(), PreyBrain.State.WANDER)


func test_overlay_shows_prey_and_scan() -> void:
	var overlay: DebugOverlay = _map.get_node("DebugOverlay")
	overlay.refresh()
	assert_string_contains(overlay.get_text(), "PREY WANDER")
	assert_string_contains(overlay.get_text(), "scan 1.00")
	assert_string_contains(overlay.get_text(), "caught 0")


func test_f4_shows_the_prey_points() -> void:
	var point: Node3D = _map.get_node("HidingSpots").get_child(0)
	var marker: MeshInstance3D = point.get_child(0)
	assert_false(marker.visible)
	_map.get_node("NoiseDebug").set_enabled(true)
	assert_true(marker.visible)
