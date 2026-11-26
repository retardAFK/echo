extends "res://tools/godot/tilleuls_places.gd"
## Generates the Versus arena of the cité des Tilleuls (spec S-024, Q24 and
## Q34, T-376), "la place de la tour": the tower, the social centre, the car
## park's yard and the paths between them, closed by building-site barriers.
## The buildings stay shut (doors and vaults nailed with boards), but the
## roofs are the point (Maxime, 26/11/2026): two metal stairs go up to the
## social centre's roof (4.3 m, no parapet: one can fall off), and the
## tower's fire escape (up to 12 m) stays open as a lookout. Low concrete
## walls give cover. Then it bakes the cité's navigation mesh with all that
## in. Uses the cité's layout constants, so the arena follows the map.
## Run after a change of the cité or of this file, then commit the outputs:
##   godot --headless res://tools/godot/build_versus_arena.tscn

const ARENA_PATH := "res://game/modes/versus/data/arenas/tilleuls_tour.tres"
const ARENA_NAVMESH_PATH := "res://game/modes/versus/data/arenas/tilleuls_tour_navmesh.res"
## Inside the barriers, in plan meters (x east, y south).
const BOUNDS := Rect2(86, 54, 94, 76)
const FENCE_HEIGHT := 2.2
const FENCE_THICKNESS := 0.1
## Boards over a doorway: a bit wider and higher than the gap, across the wall.
const BOARD_MARGIN := 0.2
const BOARD_DEPTH := 0.6
const BOARD_TOP := 2.8
## Lids over the car park's stairs and ramp: they close the holes.
const LID_HEIGHT := 1.1
## Stairs up to the roofs: their slope, their width and their landing.
const STAIR_SLOPE_DEGREES := 35.0
const ROOF_STAIR_WIDTH := 1.4
const ROOF_LANDING := 1.5
const RAMP_THICKNESS := 0.2
## Low walls for cover (Q24): [plan centre, length, along x], 1.1 m high.
const LOW_WALL_HEIGHT := 1.1
const LOW_WALL_THICKNESS := 0.4
const LOW_WALLS := [
	[Vector2(98, 66), 5.0, true],
	[Vector2(122, 64), 4.0, false],
	[Vector2(126, 76), 5.0, true],
	[Vector2(132, 88), 5.0, false],
	[Vector2(124, 110), 4.0, true],
	[Vector2(100, 125), 5.0, true],
	[Vector2(118, 126), 4.0, false],
	[Vector2(142, 126), 6.0, true],
	[Vector2(166, 126), 4.0, true],
	[Vector2(158, 104), 5.0, false],
	[Vector2(148, 112), 4.0, true],
	[Vector2(90, 96), 5.0, false],
]
## Where everyone starts (Q29): the hunted in the south-west corner, the
## boss about 60 m away, between the social centre and the car park.
const HUNTED_SPAWNS := [Vector2(93, 124), Vector2(96, 124), Vector2(99, 122), Vector2(93, 121)]
const BOSS_SPAWN := Vector2(150, 90)

var _arena := VersusArena.new()


func _ready() -> void:
	_arena.map_path = SCENE_PATH
	var lo := kit.world(BOUNDS.position.x, BOUNDS.position.y)
	_arena.bounds = Rect2(lo.x, lo.z, BOUNDS.size.x, BOUNDS.size.y)
	_add_fence()
	_nail_tower()
	_nail_social_centre()
	_close_car_park()
	_add_roof_stairs()
	_add_low_walls()
	_add_spawns()
	_bake()
	get_tree().quit()


## A box from plan (x0, y0, h0) to (x1, y1, h1).
func _box(x0: float, y0: float, x1: float, y1: float, h0: float, h1: float, look: int) -> void:
	var lo := kit.world(minf(x0, x1), minf(y0, y1), h0)
	var hi := kit.world(maxf(x0, x1), maxf(y0, y1), h1)
	var size := hi - lo
	_arena.pieces.append(ArenaPiece.make(Transform3D(Basis.IDENTITY, lo + size / 2.0), size, look))


## Boards over a doorway from a to b along a wall at the other coordinate c,
## from height h (a door, or a window to vault).
func _boards(along_x: bool, a: float, b: float, c: float, h := 0.0) -> void:
	var half := BOARD_DEPTH / 2.0
	var top := h + BOARD_TOP
	if along_x:
		_box(a - BOARD_MARGIN, c - half, b + BOARD_MARGIN, c + half, h, top, ArenaPiece.Look.BOARDS)
	else:
		_box(c - half, a - BOARD_MARGIN, c + half, b + BOARD_MARGIN, h, top, ArenaPiece.Look.BOARDS)


func _add_fence() -> void:
	var r := BOUNDS
	var t := FENCE_THICKNESS
	var look := ArenaPiece.Look.FENCE
	_box(r.position.x, r.position.y - t, r.end.x, r.position.y, 0, FENCE_HEIGHT, look)
	_box(r.position.x, r.end.y, r.end.x, r.end.y + t, 0, FENCE_HEIGHT, look)
	_box(r.position.x - t, r.position.y, r.position.x, r.end.y, 0, FENCE_HEIGHT, look)
	_box(r.end.x, r.position.y, r.end.x + t, r.end.y, 0, FENCE_HEIGHT, look)


## The tower: its hall doors, its broken window, the corridor doors onto the
## fire escape (the escape itself stays: a lookout up to the 4th storey).
func _nail_tower() -> void:
	var r := TOWER
	_boards(true, TOWER_NORTH_DOORS.x, TOWER_NORTH_DOORS.y, r.position.y)
	_boards(true, TOWER_SOUTH_DOORS.x, TOWER_SOUTH_DOORS.y, r.end.y)
	_boards(false, TOWER_VAULT_WINDOW.x, TOWER_VAULT_WINDOW.y, r.position.x)
	for level in range(1, TOWER_VISITED_STOREYS):
		_boards(false, FIRE_ESCAPE_DOOR.x, FIRE_ESCAPE_DOOR.y, r.end.x, level * STOREY)


## The social centre: its doors, and the windows one vaults (F1, F2).
func _nail_social_centre() -> void:
	var r := SOCIAL_CENTRE
	_boards(true, CENTRE_NORTH_DOORS.x, CENTRE_NORTH_DOORS.y, r.position.y)
	_boards(false, CENTRE_WEST_DOORS.x, CENTRE_WEST_DOORS.y, r.position.x)
	_boards(true, CENTRE_EMERGENCY_EXIT.x, CENTRE_EMERGENCY_EXIT.y, r.end.y)
	_boards(true, CENTRE_KITCHEN_DOOR.x, CENTRE_KITCHEN_DOOR.y, r.end.y)
	_boards(true, 144.0, 146.0, r.end.y, WINDOW_SILL - 1.0)  # F1.
	_boards(false, 72.0, 73.5, r.end.x, WINDOW_SILL - 1.0)  # F2.


## The car park stays shut: lids over its two stairs and across its ramp.
func _close_car_park() -> void:
	var look := ArenaPiece.Look.CONCRETE
	for hole: Rect2 in [CAR_PARK_STAIRS, CAR_PARK_NORTH_STAIRS]:
		_box(hole.position.x, hole.position.y, hole.end.x, hole.end.y, 0, LID_HEIGHT, look)
	var ramp := CAR_PARK_RAMP
	_box(ramp.position.x - 0.6, ramp.position.y, ramp.position.x, ramp.end.y, 0, BOARD_TOP, look)
	# The technical room's north door, by the barriers.
	_boards(
		true,
		CAR_PARK_TECHNICAL_NORTH_DOOR.x,
		CAR_PARK_TECHNICAL_NORTH_DOOR.y,
		CAR_PARK_TECHNICAL.position.y
	)


## Two metal stairs up to the social centre's roof (Maxime, 26/11/2026):
## along the south wall, rising west, and along the west wall, rising north.
func _add_roof_stairs() -> void:
	var r := SOCIAL_CENTRE
	var roof := SOCIAL_CENTRE_HEIGHT + SLAB
	var run := roof / tan(deg_to_rad(STAIR_SLOPE_DEGREES))
	var w := ROOF_STAIR_WIDTH
	# South: from x = 176 on the ground to the landing, then onto the roof.
	var start := r.end.x - 2.0
	_ramp(Vector3(start, 0, r.end.y + w / 2.0), Vector3(start - run, roof, r.end.y + w / 2.0), w)
	var landing := start - run
	_box(
		landing - ROOF_LANDING,
		r.end.y - 0.3,
		landing,
		r.end.y + w,
		roof - SLAB,
		roof,
		ArenaPiece.Look.METAL
	)
	# West: from y = 82 on the ground, north to its landing.
	var south := r.end.y - 2.0
	_ramp(
		Vector3(r.position.x - w / 2.0, 0, south),
		Vector3(r.position.x - w / 2.0, roof, south - run),
		w
	)
	var top := south - run
	_box(
		r.position.x - w,
		top - ROOF_LANDING,
		r.position.x + 0.3,
		top,
		roof - SLAB,
		roof,
		ArenaPiece.Look.METAL
	)


## A metal ramp from plan point a (x, h, y) to b, width wide, its top surface
## through both points.
func _ramp(a: Vector3, b: Vector3, width: float) -> void:
	var from := kit.world(a.x, a.z, a.y)
	var to := kit.world(b.x, b.z, b.y)
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var forward := (to - from).normalized()
	var side := flat.normalized().cross(Vector3.UP).normalized()
	var up := side.cross(forward).normalized()
	var basis := Basis(side, up, -forward)
	var size := Vector3(width, RAMP_THICKNESS, from.distance_to(to))
	var centre := (from + to) / 2.0 - up * RAMP_THICKNESS / 2.0
	_arena.pieces.append(ArenaPiece.make(Transform3D(basis, centre), size, ArenaPiece.Look.METAL))


func _add_low_walls() -> void:
	for wall: Array in LOW_WALLS:
		var centre: Vector2 = wall[0]
		var half := Vector2(wall[1], LOW_WALL_THICKNESS) / 2.0
		if not wall[2]:
			half = Vector2(half.y, half.x)
		_box(
			centre.x - half.x,
			centre.y - half.y,
			centre.x + half.x,
			centre.y + half.y,
			0,
			LOW_WALL_HEIGHT,
			ArenaPiece.Look.CONCRETE
		)


func _add_spawns() -> void:
	var boss := kit.world(BOSS_SPAWN.x, BOSS_SPAWN.y)
	var hunted := PackedVector3Array()
	for point: Vector2 in HUNTED_SPAWNS:
		hunted.append(kit.world(point.x, point.y))
	_arena.hunted_spawns = hunted
	_arena.boss_spawn = boss
	_arena.hunted_yaw = _yaw(boss - hunted[0])
	_arena.boss_yaw = _yaw(hunted[0] - boss)


## The rotation.y that faces direction (Godot looks down -z).
static func _yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Bakes the cité's navigation mesh with the arena in, and saves both.
func _bake() -> void:
	var map: Node3D = load(SCENE_PATH).instantiate()
	map.set_script(null)  # The cité as built, without starting a game.
	add_child(map)
	var builder := ArenaBuilder.new(_arena)
	builder.add_to_group(&"navigation_source")
	map.add_child(builder)
	var region: NavigationRegion3D = map.get_node("NavigationRegion3D")
	region.navigation_mesh = region.navigation_mesh.duplicate()
	var started := Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	var error := ResourceSaver.save(mesh, ARENA_NAVMESH_PATH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(ARENA_NAVMESH_PATH)
	_arena.navigation_mesh = mesh
	var arena_error := ResourceSaver.save(_arena, ARENA_PATH)
	print(
		(
			"Versus arena: %d pieces, %d polygons baked in %d ms, save errors %d %d"
			% [
				_arena.pieces.size(),
				mesh.get_polygon_count(),
				Time.get_ticks_msec() - started,
				error,
				arena_error
			]
		)
	)
