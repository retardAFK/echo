class_name Furniture
extends Node3D
## The furniture of the building interiors (spec S-016, Q7, T-241): its models
## are drawn only near the camera, so that a tower full of flats seen from the
## street costs no draw calls (constitution 2.2: 300 at worst). Set at run
## time: an override of an instanced model's child is lost in the web build.

const GROUP := &"furniture"

## Farther than this, in meters, a piece of furniture is not drawn: a room
## is smaller, and the walls hide the rooms beyond.
@export var draw_distance := 12.0


func _ready() -> void:
	add_to_group(GROUP)
	for node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = draw_distance
		geometry.visibility_range_end_margin = 2.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
