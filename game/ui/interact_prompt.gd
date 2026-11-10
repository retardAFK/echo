class_name InteractPrompt
extends CanvasLayer
## Hint at the bottom of the screen when the hunted can use something in reach,
## like a car alarm (spec S-006, T-042). The text is a translation key.
## A small dot marks the center of the screen, where the hunted aims their
## actions; it grows when something can be used there.

const DOT_IDLE := Color(1, 1, 1, 0.45)
const DOT_TARGET := Color(1, 1, 1, 0.9)
const DOT_SIZE_IDLE := 2.0
const DOT_SIZE_TARGET := 4.0

@export var player: Player

@onready var _label: Label = $Label
@onready var _dot: ColorRect = $Crosshair


func _process(_delta: float) -> void:
	var target: Node = null if not is_instance_valid(player) else player.get_interactable()
	var prompt: String = "" if target == null else target.get_prompt()
	_label.visible = prompt != ""
	if _label.visible:
		_label.text = prompt
	_dot.visible = is_instance_valid(player) and player.is_inside_tree()
	var size := DOT_SIZE_TARGET if _label.visible else DOT_SIZE_IDLE
	_dot.color = DOT_TARGET if _label.visible else DOT_IDLE
	_dot.size = Vector2(size, size)
	_dot.position = get_viewport().get_visible_rect().size / 2.0 - _dot.size / 2.0
