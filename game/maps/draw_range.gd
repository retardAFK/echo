class_name DrawRange
extends RefCounted
## Draws a node's models only near the camera (constitution 2.2: 300 draw
## calls at worst). The map has no occlusion culling: without this, every
## door, fuse box and hiding spot behind the walls of a building costs its
## draw calls. Set at run time: an override of an instanced model's child is
## lost in the web build.

## Doors and hiding spots, in meters: they stand outside too, so they fade in
## the fog first.
const OUTDOOR := 35.0
## Inner doors, in meters: seen only from inside their building.
const INDOOR := 20.0
## Fuse boxes and pickups, in meters: small, or only inside the buildings.
const SMALL := 25.0
## Drawn a little farther than the range once drawn, so a model on the edge
## does not flicker.
const MARGIN := 2.0


## Every model under `root` is drawn only closer than `distance` meters.
static func limit(root: Node, distance: float) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = distance
		geometry.visibility_range_end_margin = MARGIN
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
