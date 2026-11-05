extends GutTest
## The new scan look (spec S-005, Q5, T-032).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS := preload("res://game/data/visual_settings.tres")
const AIM_SPOT := Vector3(-24, 0, 13)
const INSIDE := Vector3(-11, 0.3, 13)

var _map: Node3D
var _avatar: MonsterAvatar
var _look: ScanLook
var _wall: ShaderMaterial


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.set_physics_process(false)
	_avatar.global_position = AIM_SPOT
	_avatar.look_at(INSIDE, Vector3.UP)
	_avatar.rotation.x = 0.0
	_look = _map.find_children("*", "ScanLook", false, false)[0]
	_look.set_process(false)  # Driven by hand.
	await wait_physics_frames(2)
	var wall: MeshInstance3D = _map.get_node("Blocks/WallNorth/MeshInstance3D")
	_wall = wall.get_surface_override_material(0)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func _scan(seconds: float) -> void:
	var delta := 1.0 / Engine.physics_ticks_per_second
	for i in roundi(seconds / delta):
		_avatar.update_scan(delta, true)
		_look.update(delta)


func test_no_scan_no_effect() -> void:
	_look.update(0.1)
	assert_eq(_look.amount, 0.0)
	var env: Environment = (_map.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_eq(env.background_color, SETTINGS.fog_color)


func test_scan_fades_in_and_reaches_the_materials() -> void:
	_scan(SETTINGS.scan_fade_time / 2.0)
	assert_between(_look.amount, 0.1, 0.9, "fades in, no hard cut")
	_scan(SETTINGS.scan_fade_time)
	assert_eq(_look.amount, 1.0)
	assert_eq(_wall.get_shader_parameter("scan_amount"), 1.0)
	assert_eq(_wall.get_shader_parameter("scan_half"), _map.get_node("Building").size / 2.0)
	assert_eq(_wall.get_shader_parameter("scan_dim"), SETTINGS.scan_dim)


func test_sky_darkens_during_scan() -> void:
	_scan(SETTINGS.scan_fade_time * 2.0)
	var env: Environment = (_map.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_lt(env.background_color.get_luminance(), SETTINGS.fog_color.get_luminance())
	assert_eq(env.fog_light_color, env.background_color)


func test_wave_leaves_every_interval() -> void:
	_scan(SETTINGS.scan_fade_time * 2.0)
	var start := _look.wave
	_scan(SETTINGS.scan_wave_interval / 2.0)
	assert_ne(_look.wave, start)
	assert_between(_look.wave, 0.0, 1.0)
	var radius: float = _wall.get_shader_parameter("scan_wave_radius")
	assert_almost_eq(radius, _look.wave * SETTINGS.scan_wave_reach, 0.001)


func test_scan_edges_are_pale_never_orange() -> void:
	var edge := SETTINGS.scan_edge_color
	assert_gt(edge.get_luminance(), 0.7)
	assert_lt(absf(edge.r - edge.b), 0.15, "pale grey-white, no orange hue")


func test_look_fades_out_after_the_scan() -> void:
	_scan(SETTINGS.scan_fade_time * 2.0)
	var delta := 1.0 / Engine.physics_ticks_per_second
	for i in roundi(SETTINGS.scan_fade_time * 2.0 / delta):
		_avatar.update_scan(delta, false)
		_look.update(delta)
	assert_eq(_look.amount, 0.0)
	assert_eq(_wall.get_shader_parameter("scan_amount"), 0.0)


func test_reticle_frames_the_scanned_building() -> void:
	var reticle: ScanReticle = _map.find_children("*", "ScanReticle", false, false)[0]
	_scan(0.2)
	var frame := ScanReticle.frame_rect(_avatar.get_camera(), _avatar.scan_target)
	assert_true(frame.has_area())
	var canvas: Control = reticle.get_node("Canvas")
	var center := canvas.size / 2.0
	assert_true(frame.has_point(center), "the building is aimed at, so it is around the center")


func test_frame_is_empty_behind_the_camera() -> void:
	_avatar.look_at(AIM_SPOT * 2.0 - INSIDE, Vector3.UP)
	_avatar.rotation.x = 0.0
	var building: Building = _map.get_node("Building")
	await wait_process_frames(1)
	assert_false(ScanReticle.frame_rect(_avatar.get_camera(), building).has_area())


func test_meter_jumps_with_noises_inside_the_building() -> void:
	var reticle: ScanReticle = _map.find_children("*", "ScanReticle", false, false)[0]
	reticle.set_process(false)
	_scan(_avatar.settings.scan_focus_time + 0.2)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, INSIDE, NoiseBus.settings.gauge_full_range)
	assert_almost_eq(reticle.level, 1.0, 0.01)
	reticle.update_meter(1.0 / ScanReticle.METER_RATE)
	assert_almost_eq(reticle.meter.back(), reticle.level, 0.01)
	reticle.update_meter(1.0)
	assert_eq(reticle.level, 0.0, "fades out")
