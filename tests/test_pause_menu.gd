extends GutTest
## Pause (spec S-009, Q6, T-080).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _map: GameMap
var _pause: PauseMenu


func before_each() -> void:
	GameSession.role = GameSession.Role.HUNTED
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_pause = _map.pause_menu
	_pause.change_scene = false


func after_each() -> void:
	NetSession.mode = NetSession.Mode.SOLO
	LocalControls.frozen = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _escape() -> void:
	var event := InputEventAction.new()
	event.action = "release_mouse"
	event.pressed = true
	_pause._input(event)


func test_the_map_has_a_pause_menu() -> void:
	assert_not_null(_pause)
	assert_false(_pause.visible)
	assert_eq(_pause.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_pause_freezes_the_game() -> void:
	_pause.pause()
	assert_true(get_tree().paused)
	assert_true(_pause.visible)
	assert_true(_pause.is_paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func test_resume() -> void:
	_pause.pause()
	_pause.resume()
	assert_false(get_tree().paused)
	assert_false(_pause.visible)


func test_escape_toggles_pause() -> void:
	_escape()
	assert_true(_pause.is_paused)
	_escape()
	assert_false(_pause.is_paused)


func test_controls_in_pause() -> void:
	_pause.pause()
	var label: Label = _pause.get_node("%Controls")
	assert_true(label.visible)
	assert_string_contains(label.text, tr("CONTROLS_PAUSE"))
	assert_true(_pause.get_node("%PauseList").item("PAUSE_RESUME").has_focus())


func test_resume_entry() -> void:
	_pause.pause()
	_pause.get_node("%PauseList").item("PAUSE_RESUME").pressed.emit()
	assert_false(_pause.is_paused)
	assert_false(get_tree().paused)


func test_online_the_game_goes_on() -> void:
	NetSession.mode = NetSession.Mode.CLIENT
	_pause.pause()
	assert_false(get_tree().paused, "online, the game is not stopped")
	assert_true(LocalControls.frozen, "the avatar stands still")
	assert_true(_pause.get_node("%OnlineNote").visible)
	assert_eq(
		_pause.get_node("%PauseList").item("PAUSE_MENU").text, tr("PAUSE_LEAVE_ONLINE").to_upper()
	)
	_pause.resume()
	assert_false(LocalControls.frozen)
	_pause.pause()
	_pause.go_to_menu()
	assert_false(LocalControls.frozen)
	assert_eq(NetSession.mode, NetSession.Mode.SOLO, "leaving the game closes the connection")


func test_no_pause_over_a_stopped_game() -> void:
	get_tree().paused = true  # The end screen stopped the game.
	assert_false(_pause.can_pause())


func test_back_to_menu_unpauses() -> void:
	_pause.pause()
	_pause.go_to_menu()
	assert_false(get_tree().paused)


func test_game_time_counts_physics_frames_only() -> void:
	# Paused, the loop gets no physics frames: only those count (no wall clock).
	var loop := GameLoop.new()
	loop.settings = preload("res://game/data/loop_settings.tres")
	loop._physics_process(0.5)
	loop._physics_process(0.25)
	assert_almost_eq(loop.get_duration(), 0.75, 0.0001)
	loop.is_over = true
	loop._physics_process(1.0)
	assert_almost_eq(loop.get_duration(), 0.75, 0.0001, "frozen once over")
	loop.free()
