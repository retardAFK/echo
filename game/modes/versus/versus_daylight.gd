class_name VersusDaylight
extends Node
## The Versus by day (spec S-025, Q7, T-405): a fun arcade fight, not the
## Traque's horror night. It gives the map's NightEnvironment the day's
## settings (data/versus_day.tres: blue sky, warm sun, light fog) and, in
## an arena, lines the façades around it with neon bars of bright colors:
## one mesh (one draw call), placed where rays from the arena's spots meet
## the walls, the same on every machine (no randomness). The Traque's
## stealth gauges (noise, breath) are hidden: R reloads, noise is no game.

const DAY := preload("res://game/modes/versus/data/versus_day.tres")
const NEON_MATERIAL := preload("res://game/modes/versus/data/neon_material.tres")
const NEON_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.65),
	Color(0.15, 0.95, 1.0),
	Color(1.0, 0.9, 0.2),
	Color(0.35, 1.0, 0.35),
	Color(0.7, 0.35, 1.0),
]
## The walls the rays meet: layers 1 and 2.
const WALLS := 1 | 2
## How far from a spot a façade may be, the heights of the bars, their size,
## and the least room between two bars.
const REACH := 30.0
const HEIGHTS: Array[float] = [2.8, 5.6]
const BAR := Vector3(3.0, 0.24, 0.1)
## Every third bar stands up instead.
const STANDING_BAR := Vector3(0.24, 2.2, 0.1)
const SPACING := 5.0
const DIRECTIONS := 12

var mode: VersusMode
## The neon bars' mesh, or null without an arena.
var neons: MeshInstance3D
## Where the bars are, for tests and spacing.
var bars: PackedVector3Array = []


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "VersusDaylight"


func _ready() -> void:
	var map := mode.get_parent()
	var night := map.get_node_or_null("WorldEnvironment") as NightEnvironment
	if night != null:
		night.settings = DAY
		night.apply()
	if mode.arena != null:
		_add_neons.call_deferred()  # Once the arena's pieces are in the physics.
	_hide_stealth_gauges.call_deferred()


func _hide_stealth_gauges() -> void:
	for node in mode.get_parent().find_children("*", "CanvasLayer", true, false):
		if node is NoiseGauge or node is BreathBar:
			(node as CanvasLayer).visible = false


## The spots the rays leave from: the arena's starts and chests.
func spots() -> PackedVector3Array:
	var arena := mode.arena
	var result := PackedVector3Array(arena.hunted_spawns)
	result.append(arena.boss_spawn)
	result.append_array(arena.chest_spots)
	return result


func _add_neons() -> void:
	var space := mode.get_viewport().world_3d.direct_space_state
	var tool := BoxTool.start()
	var count := 0
	for spot in spots():
		for height in HEIGHTS:
			for i in DIRECTIONS:
				var angle := TAU * i / DIRECTIONS
				var from := spot + Vector3.UP * height
				var to := from + Vector3(sin(angle), 0.0, cos(angle)) * REACH
				var hit := _wall(space, from, to)
				if hit.is_empty():
					continue
				var normal: Vector3 = hit.normal
				var at: Vector3 = hit.position + normal * 0.06
				if _near_a_bar(at) or not _flat(space, from, to, hit):
					continue
				bars.append(at)
				var size := STANDING_BAR if count % 3 == 2 else BAR
				var yaw := atan2(normal.x, normal.z)
				BoxTool.box(tool, at, size, NEON_COLORS[count % NEON_COLORS.size()], yaw)
				count += 1
	if count == 0:
		return
	neons = MeshInstance3D.new()
	neons.name = "Neons"
	neons.mesh = tool.commit()
	neons.material_override = NEON_MATERIAL
	neons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(neons)


## What the ray from from to to meets first: an upright wall, or nothing.
func _wall(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WALLS))
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
		return {}
	return hit


## Whether the wall hit is flat across a bar's width (not a window's side,
## a pipe or a corner): the same ray moved to either side meets the same
## plane.
func _flat(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, hit: Dictionary) -> bool:
	var normal: Vector3 = hit.normal
	var along := normal.cross(Vector3.UP).normalized() * BAR.x * 0.5
	for side in [-1.0, 1.0]:
		var other := _wall(space, from + along * side, to + along * side)
		if other.is_empty() or (other.normal as Vector3).dot(normal) < 0.95:
			return false
		if absf((other.position - hit.position).dot(normal)) > 0.15:
			return false
	return true


func _near_a_bar(at: Vector3) -> bool:
	for each in bars:
		if each.distance_to(at) < SPACING:
			return true
	return false
