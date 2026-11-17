class_name SurfaceMap
extends Resource
## The floors of a map (spec S-012, T-143), written by the map's generator
## from what it builds: the lining of each room, the paths, the playground,
## the puddles. A list of boxes, smallest first: the first box holding a
## point gives its floor. Outside every box, a point near the ground is on
## ground_kind (the dead lawn of the cité), any other on concrete.

## World boxes, smallest volume first.
@export var boxes: Array[AABB] = []
## The FloorSurface.Kind of each box.
@export var kinds := PackedInt32Array()
## Floor of the open ground.
@export var ground_kind := FloorSurface.Kind.EARTH
## Heights counted as the open ground, from x to y, in meters.
@export var ground_band := Vector2(-0.5, 0.6)


## Adds a box. Call sort() once all are in.
func add(box: AABB, kind: FloorSurface.Kind) -> void:
	boxes.append(box)
	kinds.append(kind)


## Puts the smallest boxes first.
func sort() -> void:
	var order := range(boxes.size())
	order.sort_custom(
		func(a: int, b: int) -> bool: return boxes[a].get_volume() < boxes[b].get_volume()
	)
	var sorted_boxes: Array[AABB] = []
	var sorted_kinds := PackedInt32Array()
	for i: int in order:
		sorted_boxes.append(boxes[i])
		sorted_kinds.append(kinds[i])
	boxes = sorted_boxes
	kinds = sorted_kinds


## The floor at a point (the feet).
func kind_at(point: Vector3) -> FloorSurface.Kind:
	for i in boxes.size():
		if boxes[i].has_point(point):
			return kinds[i] as FloorSurface.Kind
	if point.y >= ground_band.x and point.y <= ground_band.y:
		return ground_kind
	return FloorSurface.Kind.CONCRETE
