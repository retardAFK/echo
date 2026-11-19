class_name FloorSurfaces
extends Node
## Holds the floors of a map (spec S-012, T-143) for FloorSurface.at().

const GROUP := &"floor_surfaces"

@export var surfaces: SurfaceMap


func _ready() -> void:
	add_to_group(GROUP)
