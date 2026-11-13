class_name StartMenu
extends Control
## Start menu (spec S-004, Q1): choose to play the hunted or the monster.
## Then the goal and the controls of that role (S-009, Q5), and "Jouer".
## It is the main scene, so the choice also works in the web build.

signal role_chosen(role: GameSession.Role)

const MAP_SCENE := "res://game/maps/tilleuls/tilleuls.tscn"
const BENCH_SCENE := "res://game/bench/bench.tscn"

## Tests turn this off to stay on the menu after a choice.
@export var change_scene := true

@onready var _buttons: Control = %Buttons
@onready var _hunted_button: Button = %HuntedButton
@onready var _monster_button: Button = %MonsterButton
@onready var _role_panel: Control = %RolePanel
@onready var _goal: Label = %Goal
@onready var _controls: Label = %Controls
@onready var _play_button: Button = %PlayButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	if change_scene and not OS.has_feature("web"):
		# A server process (S-010, T-094): the lobby or one room, no menu.
		ServerBoot.parse(OS.get_cmdline_user_args())
		if ServerBoot.scene() != "":
			get_tree().change_scene_to_file.call_deferred(ServerBoot.scene())
			return
	if change_scene and Bench.is_requested():
		# Bench mode (S-009, T-075): straight to the camera tour, no menu.
		get_tree().change_scene_to_file.call_deferred(BENCH_SCENE)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hunted_button.pressed.connect(choose.bind(GameSession.Role.HUNTED))
	_monster_button.pressed.connect(choose.bind(GameSession.Role.MONSTER))
	_play_button.pressed.connect(play)
	_back_button.pressed.connect(back)
	_hunted_button.grab_focus()


## Picks a role and shows its goal and controls.
func choose(role: GameSession.Role) -> void:
	GameSession.role = role
	role_chosen.emit(role)
	_goal.text = tr(ControlsText.goal_key(role))
	_controls.text = ControlsText.controls(role)
	_buttons.visible = false
	_role_panel.visible = true
	_play_button.grab_focus()


## Back to the role choice.
func back() -> void:
	_role_panel.visible = false
	_buttons.visible = true
	_hunted_button.grab_focus()


func play() -> void:
	if change_scene:
		get_tree().change_scene_to_file(MAP_SCENE)
