class_name StartMenu
extends Control
## Home screen (spec S-013, T-162, style A): play alone or online, options
## and credits (T-167). "Jouer seul" opens the role choice (S-004, Q1), with
## the goal and the controls of the role under the cursor (S-009, Q5);
## choosing a role starts the game.
## It is the main scene, so the choice also works in the web build.

signal role_chosen(role: GameSession.Role)

const MAP_SCENE := "res://game/maps/tilleuls/tilleuls.scn"
const BENCH_SCENE := "res://game/bench/bench.tscn"
const MIX_BENCH_SCENE := "res://game/bench/mix_bench.tscn"
const LOBBY_SCENE := "res://game/ui/lobby_menu.tscn"
const ROLES := {
	"MENU_PLAY_HUNTED": GameSession.Role.HUNTED,
	"MENU_PLAY_MONSTER": GameSession.Role.MONSTER,
}

## Tests turn this off to stay on the menu after a choice.
@export var change_scene := true
@export var net_settings: NetSettings = preload("res://game/data/net_settings.tres")

@onready var _home: Control = %Home
@onready var _main_list: MenuList = %MainList
@onready var _solo: Control = %Solo
@onready var _role_list: MenuList = %RoleList
@onready var _goal: Label = %Goal
@onready var _controls: Label = %Controls
@onready var _version: Label = %Version
@onready var _foot: Control = %Foot
@onready var _options: OptionsMenu = %Options
@onready var _credits: CreditsMenu = %Credits


func _ready() -> void:
	if change_scene and not OS.has_feature("web"):
		# A server process (S-010, T-094): the lobby or one room, no menu.
		ServerBoot.parse(OS.get_cmdline_user_args())
		if ServerBoot.scene() != "":
			get_tree().change_scene_to_file.call_deferred(ServerBoot.scene())
			return
	if change_scene and MixBench.is_requested():
		# Mixing bench (S-012, T-147): typical moments heard one after the other.
		get_tree().change_scene_to_file.call_deferred(MIX_BENCH_SCENE)
		return
	if change_scene and Bench.is_requested():
		# Bench mode (S-009, T-075): straight to the camera tour, no menu.
		get_tree().change_scene_to_file.call_deferred(BENCH_SCENE)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main_list.set_item_visible("MENU_ONLINE", net_settings.show_online)
	_main_list.chosen.connect(_on_main_chosen)
	_role_list.chosen.connect(_on_role_chosen)
	_options.closed.connect(show_home)
	_credits.closed.connect(show_home)
	for key: String in ROLES:
		_role_list.item(key).focus_entered.connect(preview.bind(ROLES[key]))
	for key in LoadoutItems.KEYS:  # The hunted's gadgets (S-023, T-352).
		_role_list.item(key).focus_entered.connect(_preview_gadget.bind(key))
	LoadoutItems.refresh(_role_list)
	_role_list.item("MENU_TEST_ROOM").focus_entered.connect(_preview_test_room)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_version.text = Text.t("MENU_VERSION", version if version != "" else "dev")
	show_home()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _solo.visible:
		show_home()
		get_viewport().set_input_as_handled()


func show_home() -> void:
	_options.visible = false
	_credits.visible = false
	_foot.visible = true
	_solo.visible = false
	_home.visible = true
	_main_list.focus_first()


## The role choice of "Jouer seul".
func show_solo() -> void:
	_home.visible = false
	_solo.visible = true
	_role_list.focus_first()
	preview(GameSession.Role.HUNTED)


func show_options() -> void:
	_home.visible = false
	_foot.visible = false
	_options.open()


## The credits, from CREDITS.md (T-167).
func show_credits() -> void:
	_home.visible = false
	_foot.visible = false
	_credits.open()


## Shows the goal and the controls of a role.
func preview(role: GameSession.Role) -> void:
	_goal.text = Text.t(ControlsText.goal_key(role))
	_controls.text = ControlsText.controls(role)


## Picks a role and starts the game alone.
func choose(role: GameSession.Role) -> void:
	GameSession.role = role
	GameSession.online_seat = -1
	role_chosen.emit(role)
	play()


func play() -> void:
	if change_scene:
		LoadingScreen.open(get_tree(), MAP_SCENE)  # T-166.


## The online game menu (S-010, T-096): create or join with a code.
func play_online() -> void:
	if change_scene:
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_main_chosen(key: String) -> void:
	match key:
		"MENU_SOLO":
			show_solo()
		"MENU_ONLINE":
			play_online()
		"MENU_OPTIONS":
			show_options()
		"MENU_CREDITS":
			show_credits()


## The hunted's goal and controls, with what the gadget under the cursor does.
func _preview_gadget(key: String) -> void:
	preview(GameSession.Role.HUNTED)
	_goal.text = LoadoutItems.help(key)


## What the test room is for (S-023, Q8).
func _preview_test_room() -> void:
	_goal.text = Text.t("TEST_ROOM_GOAL")
	_controls.text = ""


func _on_role_chosen(key: String) -> void:
	if LoadoutItems.choose(_role_list, key):
		_preview_gadget(key)
	elif key == "MENU_TEST_ROOM":
		if change_scene:
			TestRoom.open(get_tree(), GameSession.Role.HUNTED)  # S-023, T-356.
	elif ROLES.has(key):
		choose(ROLES[key])
	else:
		show_home()
