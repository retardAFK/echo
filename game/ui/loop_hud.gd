class_name LoopHud
extends CanvasLayer
## The hunted's only hint about the goal (spec S-007, Q8): "Fusibles n/3" in
## small at the top of the screen, and "Objectifs n/m" for the others
## (S-018). No arrow, no marker; the map (S-017, D-018)
## shows the place only. When the monster rises a stage (S-023, Q6), a deep
## growl rolls over the cité and "Le monstre s'énerve" shows for a moment
## under it: not a game noise, the monster sees no orange from it.

const RUMBLE := preload("res://assets/audio/loop/monster_rumble.wav")

@export var game_loop: GameLoop

var _rise_left := 0.0

@onready var _label: Label = $Label
@onready var _rise: Label = $Rise
@onready var _rumble: AudioStreamPlayer = $Rumble


func _ready() -> void:
	game_loop.fuses_changed.connect(_on_fuses_changed)
	game_loop.escalated.connect(_on_escalated)
	_on_fuses_changed(game_loop.rules.found(), game_loop.rules.placed)
	_rise.visible = false
	_rumble.stream = RUMBLE
	_rumble.volume_db = game_loop.settings.rise_rumble_db


func _process(delta: float) -> void:
	if _rise_left > 0.0:
		_rise_left -= delta
		_rise.visible = _rise_left > 0.0


func _on_escalated(_stage: int) -> void:
	_rise.text = Text.t("HUD_MONSTER_RISES")
	_rise_left = game_loop.settings.rise_message_time
	_rise.visible = true
	_rumble.play()


func _on_fuses_changed(found: int, _placed: int) -> void:
	var rules := game_loop.rules
	_label.text = Text.t("HUD_FUSES", [found, rules.fuse_count]) if rules.fuse_count > 0 else ""
	var others := rules.objectives.size() - rules.fuse_count
	if others > 0:
		var done := others - rules.pending.size()
		_label.text += (
			("   " if _label.text != "" else "") + Text.t("HUD_OBJECTIVES", [done, others])
		)
