class_name InteractPrompt
extends CanvasLayer
## Hint at the bottom of the screen when the hunted can use something in reach,
## like a car alarm (spec S-006, T-042). The text is a translation key.

@export var player: Player

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var target: Node = null if not is_instance_valid(player) else player.get_interactable()
	var prompt: String = "" if target == null else target.get_prompt()
	_label.visible = prompt != ""
	if _label.visible:
		_label.text = prompt
