class_name RetroWorld
extends Node
## Gives the whole map its retro surfaces once everything is in place
## (spec S-005, T-031). Deferred, so the props and the role-specific nodes
## the map adds in its own _ready are converted too.

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")


func _ready() -> void:
	_apply.call_deferred()


func _apply() -> void:
	RetroSurface.apply_to(get_parent(), settings)
