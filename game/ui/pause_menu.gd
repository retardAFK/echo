class_name PauseMenu
extends CanvasLayer
## Pause (spec S-009, Q6, T-080): Escape freezes the game (AIs, timers,
## sounds), frees the mouse and offers to resume, read the controls or go back
## to the start menu. In a browser, Escape always frees a captured mouse first
## and the key may never reach the game: losing the mouse also pauses.

signal paused_changed(is_paused: bool)

const MENU_SCENE := "res://game/ui/start_menu.tscn"

## Tests turn this off to stay on the map.
@export var change_scene := true

var is_paused := false

var _was_captured := false

@onready var _resume: Button = %ResumeButton
@onready var _controls_button: Button = %ControlsButton
@onready var _menu: Button = %MenuButton
@onready var _controls: Label = %Controls


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume.pressed.connect(resume)
	_controls_button.pressed.connect(toggle_controls)
	_menu.pressed.connect(go_to_menu)
	_controls.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("release_mouse"):
		return
	if is_paused:
		resume()
	elif can_pause():
		pause()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not is_paused and can_pause():
		pause()  # The browser freed the mouse (Escape).
	_was_captured = captured


## Not over another screen that already stopped the game (end of game).
func can_pause() -> bool:
	return not get_tree().paused


func pause() -> void:
	is_paused = true
	visible = true
	_controls.text = ControlsText.controls(GameSession.role)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false
	_resume.grab_focus()
	paused_changed.emit(true)


## Resumes the game. Called by a click, so the browser lets it capture the mouse.
func resume() -> void:
	is_paused = false
	visible = false
	_controls.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(false)


func toggle_controls() -> void:
	_controls.visible = not _controls.visible


func go_to_menu() -> void:
	is_paused = false
	get_tree().paused = false
	if change_scene:
		get_tree().change_scene_to_file(MENU_SCENE)
