class_name InteractHighlights
extends CanvasLayer
## Small pale marks on what the hunted can use nearby (S-009, T-087, after
## Maxime's first test: "the interactive elements are hard to see"): bottles,
## alarm clocks, fuse boxes with a fuse, the transformer when carrying a fuse,
## free hiding spots, car alarms. A mark shows within highlight_range, when
## nothing stands between the eyes and the thing, and pulses gently. Pale,
## never orange: orange is noise.

## Mark half size and line width, in pixels of the 640 x 360 resolution.
const HALF_SIZE := 3.0
const LINE_WIDTH := 1.0
## A small thing gets its mark this far above its top, a big one (taller
## than BIG_HEIGHT) in its middle, in meters.
const MARK_GAP := 0.2
const BIG_HEIGHT := 1.0
## Dimmest and brightest opacity of the pulse.
const ALPHA_MIN := 0.35
const ALPHA_MAX := 0.85
## A hit this close to the mark does not hide it, in meters.
const SIGHT_MARGIN := 0.4

## The hunted Player.
@export var player: Player

## Screen positions of the marks drawn this frame.
var marks: Array[Vector2] = []

var _time := 0.0
## Mark offsets from each thing's origin, worked out once.
var _offsets := {}

@onready var _canvas: Control = $Canvas


## Whether the user would get a prompt from this thing now (it is useful to
## them), whatever the distance.
static func is_useful(node: Node, user: Node) -> bool:
	if node.has_method("wanted_by") and not node.wanted_by(user):
		return false
	var prompt: String = (
		node.get_prompt_for(user) if node.has_method("get_prompt_for") else node.get_prompt()
	)
	return prompt != ""


## Where the mark of a thing goes, from its drawn shapes: above a small
## thing, in the middle of a big one (a closet, a fuse box on a wall).
static func mark_position(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for visual: VisualInstance3D in node.find_children("*", "VisualInstance3D", true, false):
		if visual is Light3D:
			continue
		var part := visual.global_transform * visual.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return node.global_position + Vector3.UP * MARK_GAP
	var center := box.get_center()
	if box.size.y > BIG_HEIGHT:
		return center
	return Vector3(center.x, box.end.y + MARK_GAP, center.z)


func _ready() -> void:
	_canvas.draw.connect(_draw_marks)


func _process(delta: float) -> void:
	_time += delta
	marks.clear()
	var camera := get_viewport().get_camera_3d()
	if camera != null and is_instance_valid(player) and not player.is_hidden():
		update_marks(camera)
	_canvas.queue_redraw()


## Fills marks with the screen positions of the useful things in sight.
func update_marks(camera: Camera3D) -> void:
	var eye := camera.global_position
	var reach := player.settings.highlight_range
	for node: Node3D in get_tree().get_nodes_in_group(Interactable.GROUP):
		if not _offsets.has(node):
			_offsets[node] = mark_position(node) - node.global_position
		var point: Vector3 = node.global_position + _offsets[node]
		if eye.distance_to(point) > reach or camera.is_position_behind(point):
			continue
		if not is_useful(node, player) or not _in_sight(eye, point, node):
			continue
		marks.append(camera.unproject_position(point))


func _in_sight(eye: Vector3, point: Vector3, node: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, point, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider")
	if collider == node or node.is_ancestor_of(collider):
		return true
	return (hit.position as Vector3).distance_to(point) <= SIGHT_MARGIN


func _draw_marks() -> void:
	var wave := 0.5 + 0.5 * sin(_time * TAU * player.settings.highlight_pulse_rate)
	var color := Color(player.settings.highlight_color, lerpf(ALPHA_MIN, ALPHA_MAX, wave))
	for mark in marks:
		var c := mark.floor()
		var points := PackedVector2Array(
			[
				c + Vector2(0, -HALF_SIZE),
				c + Vector2(HALF_SIZE, 0),
				c + Vector2(0, HALF_SIZE),
				c + Vector2(-HALF_SIZE, 0),
				c + Vector2(0, -HALF_SIZE),
			]
		)
		_canvas.draw_polyline(points, color, LINE_WIDTH)
