class_name NoiseMarker
extends Control
## One noise heard by the playable monster (spec S-004, Q2): an orange ring at
## the noise's position on screen, with its distance, fading out.

var color := Color.WHITE
var radius := 5.0

@onready var _label: Label = $Label


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 1.5)


func set_text(text: String) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
