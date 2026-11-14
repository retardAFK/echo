class_name PauseMenu
extends CanvasLayer
## Pause (spec S-009, Q6, T-080; style A of S-013, T-164): Escape opens a band
## across the screen to resume or go back to the menu, with the controls of
## the role. Alone, the game stops (AIs, timers, sounds). Online it goes on
## and the avatar stands still while the menu is open (S-013, Q6). In a
## browser, Escape always frees a captured mouse first and the key may never
## reach the game: losing the mouse also pauses.

signal paused_changed(is_paused: bool)

const MENU_SCENE := "res://game/ui/start_menu.tscn"

## Tests turn this off to stay on the map.
@export var change_scene := true

var is_paused := false

var _was_captured := false

@onready var _list: MenuList = %PauseList
@onready var _controls: Label = %Controls
@onready var _online_note: Label = %OnlineNote
@onready var _band: Control = %Band
@onready var _options: OptionsMenu = %Options


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_list.chosen.connect(_on_chosen)
	_options.closed.connect(_on_options_closed)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("release_mouse") or _options.visible:
		return  # Escape in the options closes them first.
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


## True in an online game: the pause does not stop it.
static func is_online() -> bool:
	return NetSession.mode == NetSession.Mode.CLIENT


## Not over another screen that already stopped the game (end of game).
func can_pause() -> bool:
	return not get_tree().paused


func pause() -> void:
	is_paused = true
	visible = true
	_options.visible = false
	_band.visible = true
	var online := is_online()
	_controls.text = ControlsText.controls(GameSession.role)
	_online_note.visible = online
	_list.item("PAUSE_MENU").key = "PAUSE_LEAVE_ONLINE" if online else "PAUSE_MENU"
	if online:
		LocalControls.frozen = true
	else:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false
	_list.focus_first()
	paused_changed.emit(true)


## Resumes the game. Called by a click, so the browser lets it capture the mouse.
func resume() -> void:
	is_paused = false
	visible = false
	LocalControls.frozen = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(false)


## Back to the start menu. Online, this player leaves the game: an AI takes
## the seat (S-010, Q7) and the same code lets the player come back.
func go_to_menu() -> void:
	is_paused = false
	LocalControls.frozen = false
	get_tree().paused = false
	if is_online():
		NetSession.leave()
	if change_scene:
		get_tree().change_scene_to_file(MENU_SCENE)


func _on_chosen(key: String) -> void:
	match key:
		"PAUSE_RESUME":
			resume()
		"PAUSE_OPTIONS":
			_band.visible = false
			_options.open()
		"PAUSE_MENU":
			go_to_menu()


func _on_options_closed() -> void:
	_band.visible = true
	_list.item("PAUSE_OPTIONS").grab_focus()
