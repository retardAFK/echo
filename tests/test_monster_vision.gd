extends GutTest
## Monster vision, chase and catch in the greybox (spec S-003, T-017).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS_PATH := "res://game/data/monster_settings.tres"
## Open ground in the north of the greybox.
const OPEN_SPOT := Vector3(0, 0, -16)
## Inside the east room of the test building, and just outside its east wall.
const ROOM_SPOT := Vector3(-11, 0, 13)
const OUTSIDE_EAST := Vector3(-6, 0, 13)

var _settings: MonsterSettings
var _map: Node3D
var _monster: Monster
var _player: Player


func before_each() -> void:
	_settings = load(SETTINGS_PATH)
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_monster = _map.get_node("Monster")
	_player = _map.get_node("Player")
	await wait_physics_frames(2)


## Puts the monster at `monster_at`, looking towards `look_at_point`, and the player at `player_at`.
func _stage(monster_at: Vector3, player_at: Vector3, look_at_point: Vector3) -> void:
	_player.global_position = player_at
	_monster.global_position = monster_at
	_monster.look_at(Vector3(look_at_point.x, monster_at.y, look_at_point.z), Vector3.UP)
	_monster.set_physics_process(false)
	_monster.force_update_transform()
	_player.force_update_transform()


func _see_for(seconds: float) -> void:
	_monster.set_physics_process(true)
	await wait_seconds(seconds)


func test_view_cone_angle_and_range() -> void:
	var eye := Vector3.ZERO
	var forward := Vector3.FORWARD
	assert_true(MonsterVision.in_view_cone(eye, forward, Vector3(0, 0, -10), _settings))
	assert_true(MonsterVision.in_view_cone(eye, forward, Vector3(5, 0, -10), _settings), "27°")
	assert_false(MonsterVision.in_view_cone(eye, forward, Vector3(10, 0, -5), _settings), "63°")
	assert_false(MonsterVision.in_view_cone(eye, forward, Vector3(0, 0, 10), _settings), "behind")
	assert_false(MonsterVision.in_view_cone(eye, forward, Vector3(0, 0, -30), _settings), "too far")


func test_building_wall_blocks_sight() -> void:
	var space := _map.get_world_3d().direct_space_state
	var eye := ROOM_SPOT + Vector3.UP * _settings.ear_height
	var target := OUTSIDE_EAST + Vector3.UP * 1.6
	assert_false(MonsterVision.has_line_of_sight(space, eye, target))
	var open_eye := OPEN_SPOT + Vector3.UP * _settings.ear_height
	assert_true(MonsterVision.has_line_of_sight(space, open_eye, OPEN_SPOT + Vector3(6, 1.6, 0)))


func test_spots_then_chases_a_visible_player() -> void:
	var player_at := OPEN_SPOT + Vector3(14, 0, 0)
	_stage(OPEN_SPOT, player_at, player_at)
	_monster.brain.hear(player_at)  # Keeps the monster walking towards the player.
	await _see_for(1.3)
	assert_true(_monster.sees_player)
	assert_eq(_monster.get_state(), MonsterBrain.State.CHASE)
	assert_eq(_monster.brain.get_pace(), MonsterBrain.Pace.RUN)


func test_does_not_see_through_walls() -> void:
	_stage(ROOM_SPOT, OUTSIDE_EAST, OUTSIDE_EAST)
	await _see_for(1.0)
	assert_false(_monster.sees_player)
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)


func test_does_not_see_behind_itself() -> void:
	var player_at := OPEN_SPOT + Vector3(8, 0, 0)
	_stage(OPEN_SPOT, player_at, OPEN_SPOT - Vector3(8, 0, 0))
	_monster.set_physics_process(true)
	await wait_physics_frames(3)
	assert_false(_monster.sees_player)


func test_catch_resets_player_and_monster() -> void:
	var spawn: Vector3 = _map.spawn
	var player_at := OPEN_SPOT + Vector3(0.5, 0, 0)
	_stage(OPEN_SPOT, player_at, player_at)
	watch_signals(_monster)
	await _see_for(0.1)
	assert_signal_emitted(_monster, "player_caught")
	assert_eq(_monster.catch_count, 1)
	assert_true(_player.watching_catcher, "first it seizes the player (T-127)")
	await wait_seconds(_monster.settings.catch_show_time + 0.1)
	assert_true(_map.get_node("CaughtScreen").visible, "caught screen shown")
	assert_lt(_player.global_position.distance_to(spawn), 0.5, "player back at spawn")
	assert_gt(_monster.global_position.distance_to(spawn), 10.0, "monster far away")
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)


func test_caught_screen_hides_after_its_time() -> void:
	var screen: CaughtScreen = _map.get_node("CaughtScreen")
	screen.show_for(_settings.caught_screen_time)
	screen._process(_settings.caught_screen_time + 0.1)
	assert_false(screen.visible)


func test_caught_label_is_translated() -> void:
	TranslationServer.set_locale("fr")
	assert_eq(tr("HUD_CAUGHT"), "Attrapé")
