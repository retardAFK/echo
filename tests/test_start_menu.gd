extends GutTest
## Start menu and role choice (spec S-004, Q1, T-021).

const MENU_SCENE := preload("res://game/ui/start_menu.tscn")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _menu: StartMenu


func before_each() -> void:
	_menu = MENU_SCENE.instantiate()
	_menu.change_scene = false
	add_child_autofree(_menu)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func test_buttons_use_translation_keys() -> void:
	assert_eq(_menu.get_node("%HuntedButton").text, "MENU_PLAY_HUNTED")
	assert_eq(_menu.get_node("%MonsterButton").text, "MENU_PLAY_MONSTER")
	assert_eq(tr("MENU_PLAY_MONSTER"), "Monstre")


func test_buttons_set_the_role() -> void:
	watch_signals(_menu)
	_menu.get_node("%MonsterButton").pressed.emit()
	assert_eq(GameSession.role, GameSession.Role.MONSTER)
	assert_signal_emitted_with_parameters(_menu, "role_chosen", [GameSession.Role.MONSTER])
	_menu.get_node("%HuntedButton").pressed.emit()
	assert_eq(GameSession.role, GameSession.Role.HUNTED)


func test_choice_shows_goal_and_controls_of_the_role() -> void:
	assert_false(_menu.get_node("%RolePanel").visible)
	_menu.choose(GameSession.Role.MONSTER)
	assert_true(_menu.get_node("%RolePanel").visible)
	assert_false(_menu.get_node("%Buttons").visible)
	var controls: String = _menu.get_node("%Controls").text
	assert_string_contains(controls, tr("CONTROLS_SCAN"))
	assert_false(controls.contains(tr("CONTROLS_THROW")), "no bottles for the monster")
	assert_eq(_menu.get_node("%Goal").text, tr("GOAL_MONSTER"))
	_menu.back()
	assert_true(_menu.get_node("%Buttons").visible)
	_menu.choose(GameSession.Role.HUNTED)
	assert_string_contains(_menu.get_node("%Controls").text, tr("CONTROLS_THROW"))


func test_every_control_line_is_translated() -> void:
	for role in [GameSession.Role.HUNTED, GameSession.Role.MONSTER]:
		for key in ControlsText.keys_for(role):
			assert_ne(tr(key), key, key)
		assert_ne(tr(ControlsText.goal_key(role)), ControlsText.goal_key(role))


func test_hunted_role_keeps_the_ai_monster() -> void:
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	assert_not_null(map.get_node_or_null("Player"))
	assert_not_null(map.get_node_or_null("Monster"))
	assert_null(map.get_node_or_null("MonsterAvatar"))


func test_monster_role_replaces_player_and_ai_monster() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	assert_null(map.get_node_or_null("Player"))
	assert_null(map.get_node_or_null("Monster"))
	var avatar: MonsterAvatar = map.get_node("MonsterAvatar")
	assert_almost_eq(avatar.global_position, Vector3(-19, 0, 18), Vector3.ONE * 0.01)
	assert_true(avatar.get_camera().current)
	assert_false(map.get_node("NoiseGauge").visible, "the hunted's gauge is hidden")
