class_name DebugOverlay
extends CanvasLayer
## Developer overlay: frame rate and player gait (spec S-001, T-006).
## Shown by default in debug builds, toggled with F3 everywhere.
## Not player-facing, so its text is not translated.

const REFRESH_INTERVAL := 0.25

@export var player: Player

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


func get_text() -> String:
	return _label.text
