class_name MapPlan
extends Resource
## The plan of a map that the hunted can open (spec S-017, T-251): a few
## rectangles seen from above, like the plan at the entrance of a housing
## estate. It shows the place only: no fuse, no objective, no exit sign.
## A map's plan sits next to its scene, as <scene>_plan.tres; the plan of the
## cité des Tilleuls is made by tools/godot/build_map_plan.gd from the same
## figures as the map.
## Plan coordinates: x to the east, y to the south, in meters, from the
## north-west corner, as on the paper plan of S-006.

## What a rectangle is, which sets how it is drawn.
enum Kind {
	## Around the map, out of reach: railway, motorway, boulevard, wasteland.
	EDGE,
	## A footpath or a road inside the map.
	PATH,
	## A block of flats seen from outside only.
	BLOCK,
	## A building the hunted can go into.
	BUILDING,
	## An open place: playground, sports ground.
	PLACE,
	## A small structure with no name on the plan.
	STRUCTURE,
}

## Translation key of the map's name, the title of the plan.
@export var title_key := ""
## Size of the map, in meters.
@export var size := Vector2.ONE
## Plan point of the world origin.
@export var origin := Vector2.ZERO
@export var rects: Array[Rect2] = []
## One Kind per rectangle.
@export var kinds := PackedInt32Array()
## One translation key per rectangle, empty for no name.
@export var labels := PackedStringArray()


## Adds a rectangle, with the translation key of its name if it has one.
func add(rect: Rect2, kind: Kind, label := "") -> void:
	rects.append(rect)
	kinds.append(kind)
	labels.append(label)


## The plan point under a world position.
func to_plan(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z) + origin


## The heading of a node on the plan, in radians: 0 to the north, growing
## clockwise. A node looks toward its -Z, and the north is the world's -Z.
static func heading(node: Node3D) -> float:
	var forward := -node.global_basis.z
	return atan2(forward.x, -forward.z)


## Where the plan of a map scene is kept.
static func path_for(scene_path: String) -> String:
	return scene_path.get_basename() + "_plan.tres"


## The plan of a map scene, or null if the map has none (the greybox).
static func for_scene(scene_path: String) -> MapPlan:
	var path := path_for(scene_path)
	if scene_path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as MapPlan
