extends GutTest
## The hunted's map (spec S-017, T-251 and T-252).

const TILLEULS := preload("res://game/maps/tilleuls/tilleuls.scn")
const GREYBOX := preload("res://game/maps/greybox_test.tscn")
const SCREEN_SCENE := preload("res://game/ui/map_screen.tscn")
const PLAN := preload("res://game/maps/tilleuls/tilleuls_plan.tres")
const BuildMapPlan := preload("res://tools/godot/build_map_plan.gd")

var _screen: MapScreen
var _player: Node3D


func before_each() -> void:
	_player = Node3D.new()
	add_child_autofree(_player)
	_screen = SCREEN_SCENE.instantiate()
	_screen.plan = PLAN
	_screen.player = _player
	add_child_autofree(_screen)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED
	LocalControls.frozen = false
	get_tree().paused = false


func _press_map() -> void:
	var event := InputEventAction.new()
	event.action = MapScreen.ACTION
	event.pressed = true
	_screen._unhandled_input(event)


func test_saved_plan_is_up_to_date() -> void:
	var fresh: MapPlan = BuildMapPlan.make_plan()
	assert_eq(PLAN.rects, fresh.rects, "run tools/godot/build_map_plan.tscn again")
	assert_eq(PLAN.kinds, fresh.kinds)
	assert_eq(PLAN.labels, fresh.labels)
	assert_eq(PLAN.size, Vector2(220, 220))


func test_the_plan_is_found_next_to_its_map() -> void:
	assert_eq(MapPlan.for_scene(TILLEULS.resource_path), PLAN)
	assert_null(MapPlan.for_scene(GREYBOX.resource_path), "the greybox has no plan")
	assert_null(MapPlan.for_scene(""))


func test_every_label_is_translated() -> void:
	for key in PLAN.labels + PackedStringArray([PLAN.title_key, "MAP_HERE", "MAP_HINT"]):
		if not key.is_empty():
			assert_ne(TranslationServer.translate(key), StringName(key), key)


## No hint (S-017, Q2): the transformer and the exit tunnel have no name, and
## every building is drawn the same, visitable or not.
func test_no_hint_on_the_plan() -> void:
	for i in PLAN.rects.size():
		var text := TranslationServer.translate(PLAN.labels[i]).to_lower()
		for word in ["fusible", "sortie", "transfo", "tunnel"]:
			assert_false(text.contains(word), text)
		if PLAN.kinds[i] == MapPlan.Kind.STRUCTURE:
			assert_eq(PLAN.labels[i], "")


func test_plan_points_follow_the_paper_plan() -> void:
	assert_eq(PLAN.to_plan(Vector3.ZERO), Vector2(110, 110))
	assert_eq(PLAN.to_plan(Vector3(-110, 5, -110)), Vector2.ZERO, "north-west corner")
	assert_eq(PLAN.to_plan(Vector3(10, 0, 20)), Vector2(120, 130))


func test_heading_is_clockwise_from_north() -> void:
	_player.rotation.y = 0.0
	assert_almost_eq(MapPlan.heading(_player), 0.0, 0.001, "looks north")
	_player.rotation.y = -PI / 2.0
	assert_almost_eq(MapPlan.heading(_player), PI / 2.0, 0.001, "turned right: east")
	_player.rotation.y = PI / 2.0
	assert_almost_eq(MapPlan.heading(_player), -PI / 2.0, 0.001, "turned left: west")


func test_map_key_opens_and_closes() -> void:
	assert_false(_screen.visible, "closed at the start")
	_press_map()
	assert_true(_screen.visible)
	assert_eq(_screen.get_node("%Title").text, "Cité des Tilleuls")
	_press_map()
	assert_false(_screen.visible)


func test_map_key_is_tab_and_can_be_moved() -> void:
	assert_true(UserSettings.REMAPPABLE.has(MapScreen.ACTION))
	assert_eq(Settings._default_keys[MapScreen.ACTION], KEY_TAB)
	assert_true(ControlsText.HUNTED_KEYS.has("CONTROLS_MAP"))
	assert_false(ControlsText.MONSTER_KEYS.has("CONTROLS_MAP"), "no map for the monster")


func test_closes_when_the_game_stops() -> void:
	_screen.open()
	get_tree().paused = true
	_screen._process(0.0)
	assert_false(_screen.visible)
	_press_map()
	assert_false(_screen.visible, "not over the pause or the end screen")


func test_not_while_the_online_pause_is_open() -> void:
	_screen.open()
	LocalControls.frozen = true
	_screen._process(0.0)
	assert_false(_screen.visible)
	_press_map()
	assert_false(_screen.visible)


func test_the_marker_is_where_the_player_stands() -> void:
	var view := MapView.new()
	view.plan = PLAN
	add_child_autofree(view)
	view.size = Vector2(640, 360)
	_player.global_position = Vector3(-110, 0, -110)
	var area := view.plan_area()
	assert_almost_eq(area.size.x, area.size.y, 0.01, "a square plan")
	assert_eq(view.to_view(PLAN.to_plan(_player.global_position)), area.position)
	assert_eq(view.to_view(PLAN.size), area.end)


func test_greybox_hunted_has_no_map() -> void:
	var map: GameMap = GREYBOX.instantiate()
	add_child_autofree(map)
	assert_null(map.map_screen)


func test_hunted_gets_the_map() -> void:
	var map: GameMap = TILLEULS.instantiate()
	add_child_autofree(map)
	assert_not_null(map.map_screen)
	assert_eq(map.map_screen.plan, PLAN)
	assert_eq(map.map_screen.player, map.get_node("Player"))


func test_the_monster_has_no_map() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var monster_map: GameMap = TILLEULS.instantiate()
	add_child_autofree(monster_map)
	assert_null(monster_map.map_screen)
