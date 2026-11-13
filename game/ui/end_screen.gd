class_name EndScreen
extends CanvasLayer
## End of a game (spec S-007, Q6): who won, how long it lasted, the fuses
## placed, the noises of the hunted and the scans of the monster. "Rejouer"
## starts a new game (new fuses), "Menu" goes back to the start menu. The game
## is paused behind it.

signal replay_requested
signal menu_requested

const MENU_SCENE := "res://game/ui/start_menu.tscn"
const LOBBY_SCENE := "res://game/ui/lobby_menu.tscn"

## Tests turn this off to stay on the map after a choice.
@export var change_scene := true
## Online game (S-010, T-099): "replay" goes back to the waiting room, and
## "menu" leaves the room.
@export var online := false

## Text copied by "Copier le résumé" (S-009, Q7).
var summary := ""

@onready var _title: Label = %Title
@onready var _stats: Label = %Stats
@onready var _replay: Button = %ReplayButton
@onready var _menu: Button = %MenuButton
@onready var _copy: Button = %CopyButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_replay.pressed.connect(replay)
	_menu.pressed.connect(go_to_menu)
	_copy.pressed.connect(copy_summary)
	if online:
		_replay.text = "END_BACK_TO_LOBBY"


## Title key for the end of a game, seen from the role the player played.
static func title_key(role: GameSession.Role, hunted_won: bool) -> String:
	if role == GameSession.Role.MONSTER:
		return "END_PREY_ESCAPED" if hunted_won else "END_PREY_CAUGHT"
	return "END_ESCAPED" if hunted_won else "END_CAUGHT"


## "9 min 05 s".
static func format_duration(seconds: float) -> String:
	var total := int(seconds)
	return "%d min %02d s" % [total / 60, total % 60]


## Shows the result of a game and pauses it.
func show_result(role: GameSession.Role, game_loop: GameLoop) -> void:
	_title.text = title_key(role, game_loop.hunted_won)
	_stats.text = (
		"\n"
		. join(
			[
				tr("END_DURATION") % format_duration(game_loop.get_duration()),
				tr("END_FUSES") % [game_loop.rules.placed, game_loop.rules.fuse_count],
				tr("END_NOISES") % game_loop.noise_count,
				tr("END_SCANS") % game_loop.scan_count,
				tr("END_RUSES") % game_loop.ruse_count,
			]
		)
	)
	summary = RunSummary.format(role, game_loop, game_loop.get_average_fps())
	_copy.text = tr("END_COPY")
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_replay.grab_focus()


## Copies the summary of the game, for the questionnaire (S-009, Q7).
func copy_summary() -> void:
	DisplayServer.clipboard_set(summary)
	_copy.text = tr("END_COPIED")


func replay() -> void:
	replay_requested.emit()
	get_tree().paused = false
	if change_scene:
		if online:
			get_tree().change_scene_to_file(LOBBY_SCENE)
		else:
			get_tree().reload_current_scene()


func go_to_menu() -> void:
	menu_requested.emit()
	get_tree().paused = false
	if online:
		NetSession.leave()
	if change_scene:
		get_tree().change_scene_to_file(MENU_SCENE)
