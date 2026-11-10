class_name RetroWorld
extends Node
## Gives the whole map its retro surfaces once everything is in place
## (spec S-005, T-031). Deferred, so the props and the role-specific nodes
## the map adds in its own _ready are converted too. It also cuts every camera
## at the view distance, hidden in the fog (S-006, T-043).

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")


func _ready() -> void:
	_apply.call_deferred()


func _apply() -> void:
	RetroSurface.apply_to(get_parent(), settings)
	for camera: Camera3D in get_parent().find_children("*", "Camera3D", true, false):
		camera.far = settings.view_distance
		camera.near = settings.near_clip
