class_name LevelVisibility
extends Node
## Draws the inside of a building only on the levels near the camera (spec
## S-014, Q12, T-195). The map has no occlusion culling, so from a landing of
## the tower every door, piece of furniture and hiding spot of the storeys
## above and below, and of the other buildings, costs its draw calls behind
## the slabs and walls.
##
## Each model of the interior groups belongs to the building it stands in and
## to its level (floor 0 at ground level, -1 underground). Inside a building,
## the camera sees its own level and the ones just above and below, and the
## other buildings on its own level only (the cellar corridor joins the tower
## and the car park). Outside, it sees the levels -1 to 1 (the ramp of the car
## park, the ground floors through the doors, the first floor through the
## windows). A hidden model keeps its node visibility, its collisions and its
## gameplay: only its render layers are cleared, so no camera draws it.

## Children of the map whose models are inside the buildings.
const GROUPS := [
	"Doors",
	"Furniture",
	"InteriorDecor",
	"Hideouts",
	"HidingSpots",
	"FuseSlots",
	"Pickups",
	"Relays",
	"CodeSpots",
	"Prison",
	"Network",
]
## Height of a level, in meters.
const STOREY := 3.0
## A model belongs to the level of its lowest point, raised by this much, so
## that a lamp under a ceiling stays on the level below it.
const FOOT := 0.1
## The camera's level is measured from this far under it: an eye between
## 0.5 m and 3.5 m above a floor, standing, crouched or as the monster.
const EYE := 0.5
## Seconds between two looks at the camera.
const PERIOD := 0.1

## Models by key "building index:level": Array of [GeometryInstance3D, layers].
var _cells := {}
var _buildings: Array[Building] = []
var _key := ""
var _wait := 0.0


func _ready() -> void:
	_sort.call_deferred()


## Puts every model of the interior groups in its building and level.
func _sort() -> void:
	var map := get_parent()
	var buildings := map.get_node_or_null("Buildings")
	if buildings == null:  # A map without buildings (tests, greybox).
		set_process(false)
		return
	for node in buildings.get_children():
		if node is Building:
			_buildings.append(node)
	for group: String in GROUPS:
		var root := map.get_node_or_null(group)
		if root == null:
			continue
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			var geometry := node as GeometryInstance3D
			var box := geometry.global_transform * geometry.get_aabb()
			var foot := Vector3(box.get_center().x, box.position.y + FOOT, box.get_center().z)
			var index := _building_at(foot)
			if index < 0:
				continue
			var key := "%d:%d" % [index, level_of(foot.y)]
			if not _cells.has(key):
				_cells[key] = []
			_cells[key].append([geometry, geometry.layers])
	_key = ""


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = PERIOD
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var inside := _building_at(eye)
	var level := level_of(eye.y - EYE)
	var key := "%d:%d" % [inside, level]
	if key == _key:
		return
	_key = key
	for cell: String in _cells:
		var parts := cell.split(":")
		var shown := shows(inside, level, int(parts[0]), int(parts[1]))
		for entry: Array in _cells[cell]:
			var geometry: GeometryInstance3D = entry[0]
			if is_instance_valid(geometry):
				geometry.layers = entry[1] if shown else 0


## The level of a height in meters (0 from the ground to 3 m).
static func level_of(height: float) -> int:
	return floori(height / STOREY)


## True if the camera, in building `inside` (-1: outside) at `level`, draws
## the models of building `building` at level `cell_level`.
static func shows(inside: int, level: int, building: int, cell_level: int) -> bool:
	if inside < 0:
		return cell_level >= -1 and cell_level <= 1
	if building == inside:
		return absi(cell_level - level) <= 1
	return cell_level == level


## Models hidden right now (for the tests and the measures).
func hidden_count() -> int:
	var count := 0
	for cell: String in _cells:
		for entry: Array in _cells[cell]:
			var geometry: GeometryInstance3D = entry[0]
			if is_instance_valid(geometry) and geometry.layers == 0 and entry[1] != 0:
				count += 1
	return count


func _building_at(point: Vector3) -> int:
	for i in _buildings.size():
		if _buildings[i].contains(point):
			return i
	return -1
