class_name StartMenu
extends Control
## Start menu (spec S-004, Q1): choose to play the hunted or the monster.
## It is the main scene, so the choice also works in the web build.

signal role_chosen(role: GameSession.Role)

const MAP_SCENE := "res://game/maps/greybox_test.tscn"

## Tests turn this off to stay on the menu after a choice.
@export var change_scene := true

@onready var _hunted_button: Button = %HuntedButton
@onready var _monster_button: Button = %MonsterButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hunted_button.pressed.connect(choose.bind(GameSession.Role.HUNTED))
	_monster_button.pressed.connect(choose.bind(GameSession.Role.MONSTER))
	_hunted_button.grab_focus()


func choose(role: GameSession.Role) -> void:
	GameSession.role = role
	role_chosen.emit(role)
	if change_scene:
		get_tree().change_scene_to_file(MAP_SCENE)
