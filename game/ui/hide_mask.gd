class_name HideMask
extends CanvasLayer
## What the hidden hunted sees (spec S-008, Q6): black above and below, a thin
## band of sight through the slit of the door or the lid.

@export var player: Player

@onready var _top: ColorRect = $Top
@onready var _bottom: ColorRect = $Bottom


func _process(_delta: float) -> void:
	var hidden := is_instance_valid(player) and player.is_hidden()
	visible = hidden
	if not hidden:
		return
	var share := player.ruse_settings.slit_share
	var height := get_viewport().get_visible_rect().size.y
	var band := height * (1.0 - share) / 2.0
	_top.size.y = band
	_bottom.size.y = band
	_bottom.position.y = height - band
