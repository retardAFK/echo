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
