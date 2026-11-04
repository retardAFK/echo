class_name DebugOverlay
extends CanvasLayer
## Developer overlay: frame rate and player gait (spec S-001, T-006), and the
## monster's state, spotting gauge and catch count (spec S-003, T-018), and
## in the monster role the prey's state, the scan gauge and the catches (S-004).
## Shown by default in debug builds, toggled with F3 everywhere.
## Not player-facing, so its text is not translated.

const REFRESH_INTERVAL := 0.25

@export var player: Player
@export var monster: Monster
## Monster role (S-004): the playable monster and its AI prey.
@export var avatar: MonsterAvatar
@export var prey: Prey

var _elapsed := 0.0

@onready var _label: Label = $Label


func _ready() -> void:
	visible = OS.is_debug_build()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(delta: float) -> void:
	_elapsed += delta
	if visible and _elapsed >= REFRESH_INTERVAL:
		_elapsed = 0.0
		refresh()


func refresh() -> void:
	_label.text = "FPS %d" % Engine.get_frames_per_second()
	if player != null:
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		var gait: String = PlayerMotion.Gait.keys()[player.get_gait()]
		_label.text += "\n%s %.1f m/s" % [gait, speed]
	if monster != null and monster.brain != null:
		var state: String = MonsterBrain.State.keys()[monster.get_state()]
		_label.text += "\nMONSTER %s spot %.2f" % [state, monster.brain.spot_level]
		_label.text += "\ncaught %d" % monster.catch_count
	if avatar != null:
		var pace: String = MonsterBrain.Pace.keys()[avatar.get_pace()]
		_label.text += "\n%s scan %.2f" % [pace, avatar.scan.get_ratio()]
		_label.text += "\ncaught %d" % avatar.catch_count
	if prey != null and prey.brain != null:
		var prey_state: String = PreyBrain.State.keys()[prey.get_state()]
		var breath := " breathless" if prey.brain.is_breathless() else ""
		var warned := " warned" if prey.is_warned() else ""
		_label.text += "\nPREY %s%s%s" % [prey_state, breath, warned]


func get_text() -> String:
	return _label.text
