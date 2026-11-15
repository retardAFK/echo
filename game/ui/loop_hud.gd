class_name LoopHud
extends CanvasLayer
## The hunted's only hint about the goal (spec S-007, Q8): "Fusibles n/3" in
## small at the top of the screen. No arrow, no marker; the map (S-017, D-018)
## shows the place only.

@export var game_loop: GameLoop

@onready var _label: Label = $Label


func _ready() -> void:
	game_loop.fuses_changed.connect(_on_fuses_changed)
	_on_fuses_changed(game_loop.rules.found(), game_loop.rules.placed)


func _on_fuses_changed(found: int, _placed: int) -> void:
	_label.text = tr("HUD_FUSES") % [found, game_loop.settings.fuse_count]
