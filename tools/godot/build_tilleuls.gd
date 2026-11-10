extends Node
## Generates the cité des Tilleuls (spec S-006) from its validated paper plan
## (specs/S-006-cite-des-tilleuls/plan-map.svg): ground, borders, blocks of flats,
## visitable buildings, landmarks, gameplay points, then bakes the navigation mesh.
## Run after any change, then commit the scene and the navigation mesh:
##   godot --headless tools/godot/build_tilleuls.tscn
## (a scene rather than -s, so the autoloads the game scripts use are loaded).
## The map is only edited here: a hand edit of the scene is lost on the next run.
## Coordinates are plan coordinates (see map_kit.gd): x east, y south, meters.

const MapKit := preload("res://tools/godot/map_kit.gd")

const SCENE_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
const NAVMESH_PATH := "res://game/maps/tilleuls/tilleuls_navmesh.tres"

const MAP_SIZE := 220.0
## Ground tiles: a light only touches the few tiles around it.
const GROUND_TILE := 40.0
const GROUND_THICKNESS := 0.2
## Inside the fences, in plan meters: west fence to noise wall, exit gate to site fence.
const FENCED := Rect2(6, 2.8, 204.5, 209.4)
const NAV_BOTTOM := -5.24
const PATH_WIDTH := 5.0
const PATH_HEIGHT := 0.04
## One storey of a block of flats, in meters.
const STOREY := 3.0

const MAT_DIRT := preload("res://game/fx/materials/ground_dirt.tres")
const MAT_ASPHALT := preload("res://game/fx/materials/asphalt_floor.tres")
const MAT_CONCRETE := preload("res://game/fx/materials/concrete_wall.tres")
const MAT_OBSTACLE := preload("res://game/fx/materials/concrete_obstacle.tres")

const PLAYER := preload("res://game/entities/player/player.tscn")
const MONSTER := preload("res://game/entities/monster/monster.tscn")
## How far a fuse box looks for a wall around its slot, in meters.
const FUSE_BOX_WALL_SEARCH := 3.5
const BUILDING := preload("res://game/entities/building/building.tscn")
const FUSE_BOX := preload("res://game/entities/fuse_box/fuse_box.tscn")
const TRANSFORMER_NODE := preload("res://game/entities/transformer/transformer.tscn")
const EXIT_GATE_SCRIPT := preload("res://game/entities/exit/exit_gate.gd")
const EXIT_ZONE_SCRIPT := preload("res://game/entities/exit/exit_zone.gd")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
## The grille of the exit tunnel, and the far end of the tunnel (plan, S-007).
const EXIT_GATE := Rect2(150, 2.8, 10, 0.4)
const EXIT_GATE_HEIGHT := 3.6
const EXIT_ZONE := Rect2(150.5, 0, 9, 2.6)
const OVERLAY := preload("res://game/ui/debug_overlay.tscn")
const NOISE_DEBUG := preload("res://game/ui/noise_debug.tscn")
const GAUGE := preload("res://game/ui/noise_gauge.tscn")
const CAUGHT := preload("res://game/ui/caught_screen.tscn")
const INTERACT_PROMPT := preload("res://game/ui/interact_prompt.tscn")
const CAR_ALARM := preload("res://game/entities/car_alarm/car_alarm.tscn")
const RETRO_POST := preload("res://game/fx/retro_post.tscn")
const LAMPPOST := preload("res://game/entities/props/lamppost.tscn")
const BENCH_DIRTY := preload("res://game/entities/props/bench_dirty.tscn")
const BENCH_BROKEN := preload("res://game/entities/props/bench_broken.tscn")
const TREE_BARE := preload("res://game/entities/props/tree_bare.tscn")
const FACADE_DRESSING := preload("res://game/maps/facade_dressing.gd")
## Models of the gallery and the social centre (T-046, tools/blender/gallery.py),
## front toward +Z, origin at the bottom corner on the left seen from outside.
const SHOP_SHUTTER := preload("res://assets/models/gallery_shop_shutter.glb")
const SHOP_HALF := preload("res://assets/models/gallery_shop_half.glb")
const LAUNDRETTE := preload("res://assets/models/gallery_laundrette.glb")
const WASHERS := preload("res://assets/models/gallery_washers.glb")
const CENTRE_WINDOW := preload("res://assets/models/centre_window.glb")
const CENTRE_ENTRANCE := preload("res://assets/models/centre_entrance.glb")
const FOLDING_TABLE := preload("res://assets/models/folding_table.glb")
const CENTRE_WINDOW_WIDTH := 2.0
## Models of the car park and the garages (T-047, tools/blender/car_park.py).
const CAR_WRECK := preload("res://assets/models/car_wreck.glb")
const CAR_PARK_SIGN := preload("res://assets/models/car_park_sign.glb")
const CAR_PARK_PILLAR := preload("res://assets/models/car_park_pillar.glb")
const NEON_FIXTURE := preload("res://assets/models/neon_fixture.glb")
const GARAGE_CLOSED := preload("res://assets/models/garage_closed.glb")
const GARAGE_OPEN := preload("res://assets/models/garage_open.glb")
## Outdoor models (T-048, tools/blender/outdoor.py).
const TRANSFORMER := preload("res://assets/models/transformer.glb")
const SWING := preload("res://assets/models/swing.glb")
## Ambient sounds (T-050), made by tools/audio/ambience.py.
const WIND_SOUND := preload("res://assets/audio/ambience/wind.wav")
const MOTORWAY_SOUND := preload("res://assets/audio/ambience/motorway.wav")
const TRAIN_SOUND := preload("res://assets/audio/ambience/train.wav")
const SWING_SOUND := preload("res://assets/audio/ambience/swing_creak.wav")
const AMBIENT_TRAIN := preload("res://game/audio/ambient_train.gd")
## Where the motorway is heard from, along the east fence (plan y).
const MOTORWAY_SOURCES := [40.0, 110.0, 180.0]
const CLIMBING_FRAME := preload("res://assets/models/climbing_frame.glb")
const STADIUM_BOARD := preload("res://assets/models/stadium_board.glb")
const STADIUM_GOAL := preload("res://assets/models/stadium_goal.glb")
const STADIUM_BOARD_WIDTH := 2.0
const CAR_PARK_WRECKS := [Vector2(146, 98.5), Vector2(160, 113.5), Vector2(176, 98.5)]
## Facade modules of S-005 (3 x 3 m, front toward +Z), in FacadeDressing order.
const FACADE_MODELS := [
	preload("res://assets/models/facade_hlm_plain.glb"),
	preload("res://assets/models/facade_hlm_lit.glb"),
	preload("res://assets/models/facade_hlm_balcony.glb"),
	preload("res://assets/models/facade_hlm_walled.glb"),
	preload("res://assets/models/facade_hlm_door.glb"),
	preload("res://assets/models/facade_hlm_open.glb"),
]
## OPEN has a real hole: it dresses the visited storeys of the tower, in front
## of their window openings.
enum Module { PLAIN, LIT, BALCONY, WALLED, DOOR, OPEN }
const MODULE_WIDTH := 3.0
## Share of lit windows and of balcony columns on the upper storeys, and of
## walled-up windows on the ground floor. A door every DOOR_SPACING meters.
const LIT_SHARE := 0.15
const BALCONY_SHARE := 0.35
const WALLED_SHARE := 0.5
const DOOR_SPACING := 18.0
## The panels stand this far out of the greybox walls, so they never flicker.
const FACADE_OFFSET := 0.05
const MAP_SCRIPT := preload("res://game/maps/game_map.gd")
const NIGHT_SCRIPT := preload("res://game/fx/night_environment.gd")
const RETRO_WORLD_SCRIPT := preload("res://game/fx/retro_world.gd")

## Paths of the plan, as polylines of plan points.
const PATHS := [
	[Vector2(155, 12), Vector2(155, 50), Vector2(105, 50), Vector2(105, 185), Vector2(40, 185)],
	[Vector2(105, 120), Vector2(200, 120), Vector2(200, 200)],
	[Vector2(40, 50), Vector2(105, 50)],
	[Vector2(40, 50), Vector2(40, 185)],
]

## Blocks of flats seen from outside only (plan A to G): rectangle, storeys,
## and the porch through it, if any (x range under the block, 4 m high).
## B's porch carries the path to the exit; the porches of A and E keep a run
## across the map under 45 s (T-041).
const FACADES := {
	"BarreA": [Rect2(15, 22, 70, 12), 5, Vector2(47, 53)],
	"BarreB": [Rect2(125, 22, 70, 12), 5, Vector2(150, 160)],
	"BarreC": [Rect2(15, 60, 12, 70), 5, null],
	"BarreD": [Rect2(185, 55, 12, 55), 5, null],
	"BarreE": [Rect2(45, 192, 55, 12), 5, Vector2(70, 76)],
	"BarreF": [Rect2(125, 160, 12, 40), 4, null],
	"BarreG": [Rect2(150, 145, 45, 10), 4, null],
}
const PORCH_HEIGHT := 4.0

## Walls of the visitable buildings, in meters.
const WALL := 0.3
const SLAB := 0.3
## Above the monster (2.2 m) and its navigation height (2.25 m).
const DOOR_TOP := 2.4
const DOOR_WIDTH := 1.2
const WINDOW_SILL := 1.0
## Windows of the tower match the openings of the facade modules (T-045).
const WINDOW_TOP := 2.4
const WINDOW_WIDTH := 1.2
const WINDOW_STEP := 3.0
const WINDOW_INSET := 0.9

## Tour des Tilleuls (Q3, Q4): footprint, visitable storeys, storeys seen from outside.
const TOWER := Rect2(92, 88, 24, 24)
const TOWER_VISITED_STOREYS := 5
const TOWER_STOREYS := 13
## Stairwell: two flights side by side, landing to the south on the corridor.
const STAIR_X := 101.0
const STAIR_FLIGHT_WIDTH := 2.0
const STAIR_DIVIDER := 0.4
const STAIR_LANDING_Y := 98.5  ## South end of the flights, on the corridor.
const STAIR_FLIGHT_LENGTH := 4.0
const STAIR_MID_LANDING := 1.5
## Corridor across each storey, between the north and south flats.
const CORRIDOR := Vector2(98.5, 101.5)

const SOCIAL_CENTRE := Rect2(140, 60, 38, 24)
const SOCIAL_CENTRE_HEIGHT := 4.0
const GALLERY := Rect2(45, 135, 42, 14)
const GALLERY_HEIGHT := 3.5
const GALLERY_ARCADE_DEPTH := 4.0
const GALLERY_SHOPS := 5
const GALLERY_BACK_CORRIDOR := 2.0
## The half-raised shutter: only a crouching hunted gets under it.
const SHUTTER_TOP := 1.1

const CAR_PARK := Rect2(140, 95, 40, 22)
const CAR_PARK_DEPTH := 3.0
const CAR_PARK_RAMP := Rect2(128, 100, 12, 4)
const CAR_PARK_STAIRS := Rect2(172, 112, 6, 2.5)
const CAR_PARK_PILLAR_STEP := 8.0
const PARAPET := 1.0

const GARAGES := Rect2(9, 150, 8, 35)
const GARAGE_COUNT := 6
const GARAGE_HEIGHT := 2.5
const GARAGES_OPEN := [1, 4]

## Where the hunted may start, far from the monster (Q2).
const PLAYER_SPAWNS := [
	Vector2(45, 44), Vector2(95, 44), Vector2(32, 150), Vector2(72, 112),
	Vector2(124, 96), Vector2(170, 44),
]
const MONSTER_SPAWN := Vector2(190, 190)

## The lights fade out from this distance to the camera, over LIGHT_FADE_LENGTH
## (T-049): farther, only their baked light shows. Same as lamppost.tscn.
const LIGHT_FADE_BEGIN := 20.0
const LIGHT_FADE_LENGTH := 5.0
## Lampposts: plan position and the direction the arm points to.
const LAMPPOSTS := [
	[Vector2(158, 20), Vector2.LEFT], [Vector2(158, 46), Vector2.LEFT],
	[Vector2(130, 47), Vector2.DOWN], [Vector2(80, 47), Vector2.DOWN],
	[Vector2(50, 47), Vector2.DOWN], [Vector2(37, 80), Vector2.RIGHT],
	[Vector2(37, 112), Vector2.RIGHT], [Vector2(37, 145), Vector2.RIGHT],
	[Vector2(37, 178), Vector2.RIGHT], [Vector2(72, 188), Vector2.UP],
	[Vector2(102, 160), Vector2.RIGHT], [Vector2(108, 135), Vector2.LEFT],
	[Vector2(108, 75), Vector2.LEFT], [Vector2(135, 117), Vector2.DOWN],
	[Vector2(168, 123), Vector2.UP], [Vector2(197, 150), Vector2.RIGHT],
	[Vector2(203, 180), Vector2.LEFT], [Vector2(61, 84.5), Vector2.UP],
	[Vector2(163, 178), Vector2.DOWN],
]

## The 6 cars with an alarm (Q7), parked along the streets: plan position and
## the direction of their length.
const CAR_ALARMS := [
	[Vector2(36, 45), Vector2.RIGHT], [Vector2(120, 45), Vector2.RIGHT],
	[Vector2(205, 140), Vector2.UP], [Vector2(85, 170), Vector2.RIGHT],
	[Vector2(35, 120), Vector2.UP], [Vector2(186, 206), Vector2.RIGHT],
]

## Benches and trees: plan position and the direction they face.
const BENCHES := [
	[Vector2(52, 90), Vector2.UP, false], [Vector2(70, 90), Vector2.UP, true],
	[Vector2(110, 125), Vector2.UP, false], [Vector2(150, 178), Vector2.UP, true],
	[Vector2(44, 160), Vector2.LEFT, false],
]
const TREES := [
	Vector2(48, 68), Vector2(74, 72), Vector2(49, 95), Vector2(31, 55), Vector2(82, 160),
	Vector2(120, 140), Vector2(176, 128), Vector2(140, 40), Vector2(112, 60), Vector2(64, 120),
	Vector2(20, 186), Vector2(185, 170),
]

var kit := MapKit.new()
var _root: Node3D
var _materials := {}


func _ready() -> void:
	kit.origin = Vector2(MAP_SIZE, MAP_SIZE) / 2.0
	_root = Node3D.new()
	_root.name = "Tilleuls"
	_build_ground()
	_build_borders()
	_build_facades()
	_build_landmarks()
	_build_tower()
	_build_social_centre()
	_build_gallery()
	_build_car_park()
	_build_garages()
	kit.build(_root)
	_add_buildings()
	_add_props()
	_add_navigation()
	_add_facade_dressing()
	_add_gallery_dressing()
	_add_social_centre_dressing()
	_add_car_park_dressing()
	_add_outdoor_dressing()
	_add_ambience()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bake_light()
	_place_fuse_boxes()
	var region: NavigationRegion3D = _root.get_node("NavigationRegion3D")
	var started := Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	var error := ResourceSaver.save(mesh, NAVMESH_PATH)
	mesh.take_over_path(NAVMESH_PATH)
	print(
		"Baked %d polygons in %d ms, save error %d"
		% [mesh.get_polygon_count(), Time.get_ticks_msec() - started, error]
	)
	_root.get_parent().remove_child(_root)
	_add_gameplay()
	var packed := PackedScene.new()
	error = packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Saved %s, error %d" % [SCENE_PATH, error])
	_root.free()
	get_tree().quit(error)


# --- Ground and borders -----------------------------------------------------


func _build_ground() -> void:
	var holes: Array[Rect2] = [CAR_PARK_RAMP, CAR_PARK_STAIRS]
	kit.slab_tiles(
		"Tile", Rect2(0, 0, MAP_SIZE, MAP_SIZE), holes, -GROUND_THICKNESS, 0.0, MAT_DIRT,
		GROUND_TILE
	)
	var roads := kit.structure("Paths", "Ground")
	for line: Array in PATHS:
		for i in line.size() - 1:
			_path_segment(roads, line[i], line[i + 1])
	# Outside the fences: the motorway to the east, the boulevard to the south.
	kit.box(roads, 211, 10, 220, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)
	kit.box(roads, 0, 213, 211, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


## A strip of asphalt between two plan points, a little wider than the path so
## the corners join.
func _path_segment(s: MapKit.Structure, a: Vector2, b: Vector2) -> void:
	var half := PATH_WIDTH / 2.0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half
	kit.box(s, lo.x, lo.y, hi.x, hi.y, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


func _build_borders() -> void:
	# North: railway embankment, crossed by the exit tunnel (closed until S-007).
	var rail := kit.structure("Embankment")
	kit.box(rail, 0, 0, 150, 10, 0, 6, MAT_OBSTACLE)
	kit.box(rail, 160, 0, 220, 10, 0, 6, MAT_OBSTACLE)
	kit.box(rail, 150, 0, 160, 10, 3.6, 6, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.box(rail, 0, 1, 220, 2, 6, 6.6, MAT_OBSTACLE, MapKit.Kind.GHOST)  # Track ballast.
	var tunnel := kit.structure("ExitTunnel")
	kit.box(tunnel, 149.5, 10, 150.5, 12, 0, 6, MAT_CONCRETE)
	kit.box(tunnel, 159.5, 10, 160.5, 12, 0, 6, MAT_CONCRETE)
	kit.box(tunnel, 150, 10, 160, 12, 3.6, 6, MAT_CONCRETE, MapKit.Kind.FLOOR)
	# The grille closing the tunnel is the ExitGate, a node of its own (S-007).
	# Past the north mouth, out of the cité: an invisible wall, the hunted who
	# gets there is already out (ExitZone).
	kit.box(tunnel, 150, -0.5, 160, 0, 0, 6, null)
	# East: noise wall along the motorway.
	var east := kit.structure("NoiseWall")
	kit.box(east, 210, 10, 210.5, 220, 0, 5, MAT_CONCRETE)
	# South: site fences across the boulevard. West: wasteland fence.
	var south := kit.structure("SiteFence")
	kit.box(south, 6, 212, 210, 212.2, 0, 2.2, _material("fence"))
	var west := kit.structure("WastelandFence")
	kit.box(west, 6, 10, 6.1, 212.2, 0, 2.2, _material("fence"))


# --- Blocks of flats --------------------------------------------------------


func _build_facades() -> void:
	for facade_name: String in FACADES:
		var rect: Rect2 = FACADES[facade_name][0]
		var height: float = FACADES[facade_name][1] * STOREY
		var porch: Variant = FACADES[facade_name][2]
		var s := kit.structure(facade_name)
		var y0 := rect.position.y
		var y1 := rect.end.y
		if porch == null:
			kit.box(s, rect.position.x, y0, rect.end.x, y1, 0, height, MAT_CONCRETE)
			continue
		kit.box(s, rect.position.x, y0, porch.x, y1, 0, height, MAT_CONCRETE)
		kit.box(s, porch.y, y0, rect.end.x, y1, 0, height, MAT_CONCRETE)
		kit.box(s, porch.x, y0, porch.y, y1, PORCH_HEIGHT, height, MAT_CONCRETE, MapKit.Kind.FLOOR)


# --- Visitable buildings (Q3) -----------------------------------------------


func _build_tower() -> void:
	var s := kit.structure("Tower")
	var r := TOWER
	var inner := r.grow(-WALL)
	var top := TOWER_VISITED_STOREYS * STOREY
	var east := STAIR_X + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var flights_north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH
	var stair_north := flights_north - STAIR_MID_LANDING
	var hole := Rect2(STAIR_X, stair_north, east - STAIR_X, STAIR_LANDING_Y - stair_north)
	# Upper mass, seen from the whole cité, with its red light on top.
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, top, TOWER_STOREYS * STOREY, MAT_CONCRETE)
	for level in TOWER_VISITED_STOREYS:
		var h := level * STOREY
		var windows: Array = [] if level == 0 else _windows(r.position.x, r.end.x, h)
		# Outer walls: entrances north and south on the ground floor.
		var north_gaps: Array = [[106.0, 110.0, DOOR_TOP]] if level == 0 else windows
		var south_gaps: Array = [[102.0, 108.0, DOOR_TOP]] if level == 0 else windows
		kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, north_gaps)
		kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, south_gaps)
		var side: Array = [] if level == 0 else _windows(r.position.y, r.end.y, h)
		kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, side)
		kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, side)
		# Floor: the ground floor stands on the ground, the others have a hole for the stairs.
		if level > 0:
			for piece in MapKit.subtract(inner, hole):
				kit.box(s, piece.position.x, piece.position.y, piece.end.x, piece.end.y, h - SLAB, h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
		else:
			kit.box(s, inner.position.x, inner.position.y, inner.end.x, inner.end.y, 0, 0.03, MAT_OBSTACLE, MapKit.Kind.GHOST)
		_tower_stairs(s, h, level == TOWER_VISITED_STOREYS - 1)
		if level == 0:
			_tower_ground_floor(s)
		else:
			_tower_flats(s, h, level)
	# Stairwell walls, west, east and north, from the ground to the top.
	kit.wall_y(s, stair_north - WALL, STAIR_LANDING_Y, STAIR_X - WALL / 2, 0, top, WALL, MAT_CONCRETE)
	kit.wall_y(s, stair_north - WALL, STAIR_LANDING_Y, east + WALL / 2, 0, top, WALL, MAT_CONCRETE)
	kit.wall_x(s, STAIR_X - WALL, east + WALL, stair_north - WALL / 2, 0, top, WALL, MAT_CONCRETE)
	var beacon := _material("beacon")
	var c := r.get_center()
	kit.box(s, c.x - 0.3, c.y - 0.3, c.x + 0.3, c.y + 0.3, TOWER_STOREYS * STOREY, TOWER_STOREYS * STOREY + 0.6, beacon, MapKit.Kind.GHOST)


## One storey of stairs: flight up to the north, mid landing, flight back south.
## On the last visitable storey a grille closes the way up (Q4).
func _tower_stairs(s: MapKit.Structure, h: float, last: bool) -> void:
	var half := STOREY / 2.0
	var west_end := STAIR_X + STAIR_FLIGHT_WIDTH
	var east_start := west_end + STAIR_DIVIDER
	var east := east_start + STAIR_FLIGHT_WIDTH
	var north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH
	kit.ramp(s, STAIR_X, STAIR_LANDING_Y, west_end, north, h, h + half, false, MAT_OBSTACLE)
	kit.box(s, STAIR_X, north - STAIR_MID_LANDING, east, north, h + half - SLAB, h + half, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.ramp(s, east_start, north, east, STAIR_LANDING_Y, h + half, h + STOREY, false, MAT_OBSTACLE)
	kit.box(s, west_end, north, east_start, STAIR_LANDING_Y, h, h + STOREY, MAT_CONCRETE)
	if last:
		kit.box(s, STAIR_X, STAIR_LANDING_Y - 0.15, west_end, STAIR_LANDING_Y, h, h + STOREY, _material("grille"))


## Ground floor: a hall through the tower, the bin room (open) and a locked
## technical room.
func _tower_ground_floor(s: MapKit.Structure) -> void:
	var r := TOWER
	# Technical room, north-west, locked.
	kit.wall_y(s, r.position.y, STAIR_LANDING_Y, 99.0, 0, STOREY, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, 99.0, STAIR_LANDING_Y, 0, STOREY, WALL, MAT_CONCRETE)
	# Bin room, south-west, open.
	kit.wall_x(s, r.position.x, 99.0, 104.0, 0, STOREY, WALL, MAT_CONCRETE, [[95.0, 96.4, DOOR_TOP]])
	kit.wall_y(s, 104.0, r.end.y, 99.0, 0, STOREY, WALL, MAT_CONCRETE)
	# Letter boxes along the east wall of the hall.
	kit.box(s, 114.6, 92.0, 115.7, 97.0, 0.8, 1.8, MAT_OBSTACLE, MapKit.Kind.FLOOR)


## Flats around the corridor: two open per landing, the others locked (Q4).
func _tower_flats(s: MapKit.Structure, h: float, level: int) -> void:
	var r := TOWER
	var top := h + STOREY
	var north := CORRIDOR.x
	var south := CORRIDOR.y
	var stair_east := STAIR_X + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var open: Array = [[0, 3], [1, 2], [0, 2], [1, 3]][level - 1]
	# Flats: 0 north-west, 1 north-east, 2 south-west, 3 south-east.
	var door := func(flat: int, at: float) -> Array:
		return [[at, at + DOOR_WIDTH, h + DOOR_TOP]] if open.has(flat) else []
	kit.wall_x(s, r.position.x, STAIR_X - WALL, north, h, top, WALL, MAT_CONCRETE, door.call(0, 97.0))
	kit.wall_x(s, stair_east + WALL, r.end.x, north, h, top, WALL, MAT_CONCRETE, door.call(1, 108.0))
	kit.wall_x(s, r.position.x, 104.0, south, h, top, WALL, MAT_CONCRETE, door.call(2, 100.0))
	kit.wall_x(s, 104.0, r.end.x, south, h, top, WALL, MAT_CONCRETE, door.call(3, 106.0))
	kit.wall_y(s, south, r.end.y, 104.0, h, top, WALL, MAT_CONCRETE)
	# North flats end at the stairwell; a closet fills the gap north of it.
	kit.wall_y(s, r.position.y, north, STAIR_X - WALL / 2, h, top, WALL, MAT_CONCRETE)
	kit.wall_y(s, r.position.y, north, stair_east + WALL / 2, h, top, WALL, MAT_CONCRETE)
	# Inside each open flat, a partition with a doorway between two rooms.
	for flat: int in open:
		match flat:
			0:
				kit.wall_y(s, r.position.y, north, 96.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]])
			1:
				kit.wall_y(s, r.position.y, north, 111.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]])
			2:
				kit.wall_x(s, r.position.x, 104.0, 107.0, h, top, WALL, MAT_CONCRETE, [[97.0, 98.2, h + DOOR_TOP]])
			3:
				kit.wall_x(s, 104.0, r.end.x, 107.0, h, top, WALL, MAT_CONCRETE, [[110.0, 111.2, h + DOOR_TOP]])


## Window openings of a storey at height h, one every WINDOW_STEP meters.
func _windows(from: float, to: float, h: float) -> Array:
	var gaps: Array = []
	var at := from + WINDOW_INSET
	while at + WINDOW_WIDTH <= to:
		gaps.append([at, at + WINDOW_WIDTH, h + WINDOW_TOP, h + WINDOW_SILL])
		at += WINDOW_STEP
	return gaps


func _build_social_centre() -> void:
	var s := kit.structure("SocialCentre")
	var r := SOCIAL_CENTRE
	var h := SOCIAL_CENTRE_HEIGHT
	var hall_east := 160.0
	var office_west := 163.0
	# Outer walls: entrances north (corridor) and west (great hall), windows.
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, 0, h, WALL, MAT_CONCRETE, [[160.4, 162.6, DOOR_TOP], [144.0, 146.0, 2.4, 1.0], [150.0, 152.0, 2.4, 1.0], [166.0, 168.0, 2.4, 1.0], [172.0, 174.0, 2.4, 1.0]])
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[144.0, 146.0, 2.4, 1.0], [152.0, 154.0, 2.4, 1.0], [168.0, 170.0, 2.4, 1.0]])
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE, [[70.0, 73.0, DOOR_TOP]])
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[64.0, 65.5, 2.4, 1.0], [72.0, 73.5, 2.4, 1.0], [80.0, 81.5, 2.4, 1.0]])
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, h, h + SLAB, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# Great hall and corridor, double doors between them.
	kit.wall_y(s, r.position.y, r.end.y, hall_east, 0, h, WALL, MAT_CONCRETE, [[66.0, 68.0, DOOR_TOP], [76.0, 78.0, DOOR_TOP]])
	# Offices along the corridor.
	kit.wall_y(s, r.position.y, r.end.y, office_west, 0, h, WALL, MAT_CONCRETE, [[63.0, 64.2, DOOR_TOP], [71.0, 72.2, DOOR_TOP], [79.0, 80.2, DOOR_TOP]])
	kit.wall_x(s, office_west, r.end.x, 68.0, 0, h, WALL, MAT_CONCRETE)
	kit.wall_x(s, office_west, r.end.x, 76.0, 0, h, WALL, MAT_CONCRETE)
	# Few hiding places in the hall: a stage and four tables.
	kit.box(s, 140.3, 64.0, 144.0, 80.0, 0, 0.6, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	for t: Vector2 in [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]:
		kit.box(s, t.x - 1.0, t.y - 0.5, t.x + 1.0, t.y + 0.5, 0, 0.75, null, MapKit.Kind.FLOOR)
	for d: Vector2 in [Vector2(172, 64), Vector2(172, 72), Vector2(172, 80)]:
		kit.box(s, d.x - 0.8, d.y - 0.4, d.x + 0.8, d.y + 0.4, 0, 0.75, null, MapKit.Kind.FLOOR)


func _build_gallery() -> void:
	var s := kit.structure("Gallery")
	var r := GALLERY
	var h := GALLERY_HEIGHT
	var front := r.position.y + GALLERY_ARCADE_DEPTH
	var back := r.end.y - GALLERY_BACK_CORRIDOR
	var width := r.size.x / GALLERY_SHOPS
	# Arcade roof on pillars.
	kit.box(s, r.position.x, r.position.y, r.end.x, front, h - SLAB, h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	var x := r.position.x + 0.3
	while x < r.end.x:
		kit.box(s, x - 0.2, r.position.y + 0.1, x + 0.2, r.position.y + 0.5, 0, h - SLAB, MAT_CONCRETE)
		x += width
	kit.box(s, r.end.x - 0.5, r.position.y + 0.1, r.end.x - 0.1, r.position.y + 0.5, 0, h - SLAB, MAT_CONCRETE)
	# Shop fronts: the laundrette (2nd) is open, the 4th has its shutter half up.
	var laundrette := r.position.x + width
	var shutter := r.position.x + 3 * width
	kit.wall_x(s, r.position.x, r.end.x, front, 0, h, WALL, MAT_CONCRETE, [[laundrette + 2.0, laundrette + 4.4, DOOR_TOP], [shutter + 2.0, shutter + 5.0, SHUTTER_TOP]])
	# Back wall, east and west walls, roof.
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_y(s, front, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_y(s, front, r.end.y, r.end.x - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[back + 0.2, r.end.y - 0.3, DOOR_TOP]])
	kit.box(s, r.position.x, front, r.end.x, r.end.y, h, h + SLAB, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# Shops side by side, a delivery corridor behind them.
	for i in range(1, GALLERY_SHOPS):
		kit.wall_y(s, front, back, r.position.x + i * width, 0, h, WALL, MAT_CONCRETE)
	var back_doors: Array = [[laundrette + 6.0, laundrette + 7.2, DOOR_TOP], [shutter + 6.0, shutter + 7.2, DOOR_TOP]]
	kit.wall_x(s, r.position.x, r.end.x, back, 0, h, WALL, MAT_CONCRETE, back_doors)
	# Washing machines along the laundrette walls.
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		kit.box(s, mx - 0.6, back - 1.0, mx + 0.6, back - 0.2, 0, 0.9, null, MapKit.Kind.FLOOR)


func _build_car_park() -> void:
	var s := kit.structure("CarPark")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ramp := CAR_PARK_RAMP
	var stairs := CAR_PARK_STAIRS
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, floor_h - SLAB, floor_h, MAT_ASPHALT, MapKit.Kind.FLOOR)
	# Retaining walls; the ramp comes in through the west one.
	var ceiling := -GROUND_THICKNESS
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE, [[ramp.position.y, ramp.end.y, ceiling]])
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	# Pillars every 8 m.
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			kit.box(s, px - 0.25, py - 0.25, px + 0.25, py + 0.25, floor_h, ceiling, MAT_CONCRETE)
		px += CAR_PARK_PILLAR_STEP
	# Car ramp from the ground down to the car park, with its side walls.
	kit.ramp(s, ramp.position.x, ramp.position.y, ramp.end.x, ramp.end.y, 0, floor_h, true, MAT_ASPHALT)
	kit.wall_x(s, ramp.position.x, ramp.end.x, ramp.position.y - WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_x(s, ramp.position.x, ramp.end.x, ramp.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	# Emergency stairs up to the slab in the south-east corner, a railing around them.
	kit.ramp(s, stairs.position.x, stairs.position.y, stairs.end.x, stairs.end.y, floor_h, 0, true, MAT_OBSTACLE)
	kit.wall_x(s, stairs.position.x - WALL, stairs.end.x, stairs.position.y - WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_x(s, stairs.position.x - WALL, stairs.end.x, stairs.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_y(s, stairs.position.y, stairs.end.y, stairs.position.x - WALL / 2, 0, PARAPET, WALL, MAT_CONCRETE)
	# Parked wrecks to hide behind.
	for c: Vector2 in CAR_PARK_WRECKS:
		kit.box(s, c.x - 1.0, c.y - 2.1, c.x + 1.0, c.y + 2.1, floor_h, floor_h + 1.3, null, MapKit.Kind.FLOOR)
	# "P" sign at the ramp.
	kit.box(s, 126.6, 99.4, 126.8, 99.6, 0, 2.6, _material("metal"), MapKit.Kind.FLOOR)


func _build_garages() -> void:
	var s := kit.structure("Garages")
	var r := GARAGES
	var h := GARAGE_HEIGHT
	var width := r.size.y / GARAGE_COUNT
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, h, h + 0.2, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	var doors: Array = []
	for i in GARAGE_COUNT:
		var y0 := r.position.y + i * width
		if i > 0:
			kit.wall_x(s, r.position.x, r.end.x, y0, 0, h, WALL, MAT_CONCRETE)
		if GARAGES_OPEN.has(i):
			doors.append([y0 + 0.5, y0 + width - 0.5, DOOR_TOP])
			# Junk inside: a workbench and boxes.
			kit.box(s, r.position.x + 0.4, y0 + 0.6, r.position.x + 2.0, y0 + 2.2, 0, 1.0, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, 0, h, WALL, _material("garage_door"), doors)


# --- Outdoor landmarks ------------------------------------------------------


func _build_landmarks() -> void:
	_build_playground()
	_build_city_stadium()
	var transformer := kit.structure("Transformer")
	kit.box(transformer, 96, 150, 105, 157, 0, 2.6, null)  # Dressed by its model (T-048).


func _build_playground() -> void:
	var s := kit.structure("Playground")
	var low := MapKit.Kind.FLOOR
	# Kerb around the sand.
	kit.box(s, 50, 70, 72, 70.3, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 50, 91.7, 72, 92, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 50, 70.3, 50.3, 91.7, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 71.7, 70.3, 72, 91.7, 0, 0.25, MAT_OBSTACLE, low)
	# Swing posts, climbing frame and slide: only their collisions, the models
	# dress them (T-048).
	for x: float in [57.0, 65.0]:
		kit.box(s, x - 0.1, 79.0, x + 0.1, 79.2, 0, 2.4, null, low)
		kit.box(s, x - 0.1, 81.8, x + 0.1, 82.0, 0, 2.4, null, low)
	kit.box(s, 53, 73, 56, 76, 0, 1.6, null, low)
	kit.ramp(s, 56, 74, 59.5, 75, 1.6, 0.2, true, null, 0.1)


func _build_city_stadium() -> void:
	var s := kit.structure("CityStadium")
	var boards: Material = null  # Only the collisions: the models dress them (T-048).
	var h := 1.1
	# Boards with an opening on the west and the north sides.
	kit.wall_x(s, 148, 178, 180, 0, h, 0.15, boards, [[160, 166, h]])
	kit.wall_x(s, 148, 178, 200, 0, h, 0.15, boards)
	kit.wall_y(s, 180, 200, 148, 0, h, 0.15, boards, [[188, 192, h]])
	kit.wall_y(s, 180, 200, 178, 0, h, 0.15, boards)
	# Goals at both ends.
	for x: float in [149.5, 176.5]:
		kit.box(s, x - 0.06, 188.5, x + 0.06, 188.62, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 191.38, x + 0.06, 191.5, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 188.5, x + 0.06, 191.5, 1.9, 2, boards, MapKit.Kind.GHOST)


# --- Props, lights and gameplay nodes ---------------------------------------


## Scan volumes (Q6) with their lights, and the fuse slots (Q5).
## Each entry: plan rectangle, floor and top heights, lights, fuse slots.
func _buildings() -> Dictionary:
	var tower_top := TOWER_VISITED_STOREYS * STOREY
	return {
		"Tower": [TOWER, 0.0, tower_top,
			[[Vector3(104, 2.6, 92), 6.0], [Vector3(96, 8.6, 100), 6.0], [Vector3(112, 14.6, 100), 6.0]],
			[Vector3(95.5, 0, 108), Vector3(113, 6, 93), Vector3(96, 9, 109), Vector3(113, 12, 108)]],
		"SocialCentre": [SOCIAL_CENTRE, 0.0, SOCIAL_CENTRE_HEIGHT,
			[[Vector3(151, 3.4, 72), 9.0], [Vector3(161.5, 3.4, 72), 5.0]],
			[Vector3(142, 0, 62), Vector3(176, 0, 62), Vector3(176, 0, 74), Vector3(170, 0, 82)]],
		"Gallery": [GALLERY, 0.0, GALLERY_HEIGHT,
			[[Vector3(58, 2.9, 143), 5.0], [Vector3(66, 2.8, 137), 6.0]],
			[Vector3(55, 0, 141), Vector3(61, 0, 145), Vector3(76, 0, 142), Vector3(84, 0, 148)]],
		"CarPark": [CAR_PARK, -CAR_PARK_DEPTH, 0.0,
			[[Vector3(152, -0.6, 106), 7.0], [Vector3(170, -0.6, 106), 7.0]],
			[Vector3(142, -3, 97), Vector3(178, -3, 97), Vector3(142, -3, 115), Vector3(166, -3, 115)]],
		"Garages": [GARAGES, 0.0, GARAGE_HEIGHT, [], []],
	}


func _add_buildings() -> void:
	var parent := Node3D.new()
	parent.name = "Buildings"
	_add(parent)
	var slots_parent := Node3D.new()
	slots_parent.name = "FuseSlots"
	_add(slots_parent)
	var data := _buildings()
	for building_name: String in data:
		var entry: Array = data[building_name]
		var rect: Rect2 = entry[0]
		var bottom: float = entry[1]
		var top: float = entry[2]
		var building: Node3D = BUILDING.instantiate()
		building.name = building_name
		var center := rect.get_center()
		building.position = kit.world(center.x, center.y, (bottom + top) / 2.0)
		building.set("size", Vector3(rect.size.x, top - bottom, rect.size.y))
		parent.add_child(building)
		building.owner = _root
		for i in entry[3].size():
			var spot: Vector3 = entry[3][i][0]
			var light := OmniLight3D.new()
			light.name = "Light%d" % (i + 1)
			light.light_color = Color(1, 0.96, 0.88)
			light.omni_range = entry[3][i][1]
			building.add_child(light)
			light.owner = _root
			light.position = kit.world(spot.x, spot.z, spot.y) - building.position
		if entry[4].is_empty():
			continue
		var slots := Node3D.new()
		slots.name = building_name
		slots_parent.add_child(slots)
		slots.owner = _root
		for i in entry[4].size():
			var at: Vector3 = entry[4][i]
			var marker := Marker3D.new()
			marker.name = "Slot%d" % (i + 1)
			marker.position = kit.world(at.x, at.z, at.y)
			marker.add_to_group("fuse_slot", true)
			slots.add_child(marker)
			marker.owner = _root


## The transformer, the grille of the exit and the far end of the tunnel (S-007).
func _add_loop() -> void:
	var transformer := TRANSFORMER_NODE.instantiate()
	transformer.position = kit.world(100.5, 153.5)
	_add(_named(transformer, "TransformerPanel"))
	var gate := AnimatableBody3D.new()
	gate.set_script(EXIT_GATE_SCRIPT)
	gate.set("settings", LOOP_SETTINGS)
	gate.set("rise", EXIT_GATE_HEIGHT)
	var center := EXIT_GATE.get_center()
	gate.position = kit.world(center.x, center.y)
	_add(_named(gate, "ExitGate"))
	var size := Vector3(EXIT_GATE.size.x, EXIT_GATE_HEIGHT, EXIT_GATE.size.y)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	box.material = _material("grille")
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	gate.add_child(mesh)
	mesh.owner = _root
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position.y = size.y / 2.0
	gate.add_child(shape)
	shape.owner = _root
	var zone := Area3D.new()
	zone.set_script(EXIT_ZONE_SCRIPT)
	center = EXIT_ZONE.get_center()
	zone.position = kit.world(center.x, center.y, 2.0)
	_add(_named(zone, "ExitZone"))
	var zone_shape := CollisionShape3D.new()
	zone_shape.name = "CollisionShape3D"
	zone_shape.shape = BoxShape3D.new()
	zone_shape.shape.size = Vector3(EXIT_ZONE.size.x, 4.0, EXIT_ZONE.size.y)
	zone.add_child(zone_shape)
	zone_shape.owner = _root


## A fuse box on the nearest wall of each fuse slot (S-007, Q1). The slot
## marker stays in front of it: it is where the AI prey stands to use the box.
func _place_fuse_boxes() -> void:
	var space := _root.get_world_3d().direct_space_state
	for marker: Node3D in _root.get_node("FuseSlots").find_children("Slot*", "Marker3D"):
		var from := marker.global_position + Vector3.UP * 1.3
		var best: Vector3
		var best_distance := FUSE_BOX_WALL_SEARCH
		var facing := Vector3.BACK
		for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var query := PhysicsRayQueryParameters3D.create(
				from, from + direction * FUSE_BOX_WALL_SEARCH, MapKit.WALLS_LAYER
			)
			var hit := space.intersect_ray(query)
			if hit and from.distance_to(hit.position) < best_distance:
				best_distance = from.distance_to(hit.position)
				best = hit.position
				facing = -direction
		var box: Node3D = FUSE_BOX.instantiate()
		box.name = "FuseBox"
		box.set("building_name", String(marker.get_parent().name))
		marker.add_child(box)
		box.owner = _root
		if best_distance < FUSE_BOX_WALL_SEARCH:
			box.global_position = Vector3(best.x, marker.global_position.y, best.z) + facing * 0.01
		else:
			push_warning("No wall near %s" % marker.get_path())
		box.global_rotation.y = atan2(facing.x, facing.z)


func _add_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	_root.add_child(props)
	props.owner = _root
	props.add_to_group("navigation_source", true)
	for i in LAMPPOSTS.size():
		_place(props, LAMPPOST, "Lamppost%d" % (i + 1), LAMPPOSTS[i][0], LAMPPOSTS[i][1])
	for i in BENCHES.size():
		var scene := BENCH_BROKEN if BENCHES[i][2] else BENCH_DIRTY
		_place(props, scene, "Bench%d" % (i + 1), BENCHES[i][0], BENCHES[i][1])
	for i in TREES.size():
		var turn := Vector2.from_angle(i * 1.7)
		_place(props, TREE_BARE, "Tree%d" % (i + 1), TREES[i], turn)
	_add_light(props, "TunnelLight", Vector2(155, 8), 3.2, Color(0.75, 0.85, 1.0), 1.2, 7.0)
	var cars := Node3D.new()
	cars.name = "CarAlarms"
	_add(cars)
	cars.add_to_group("navigation_source", true)
	for i in CAR_ALARMS.size():
		_place(cars, CAR_ALARM, "Car%d" % (i + 1), CAR_ALARMS[i][0], CAR_ALARMS[i][1])
	_add_light(props, "TowerBeacon", Vector2(104, 100), TOWER_STOREYS * STOREY + 1.0, Color(1, 0.15, 0.1), 2.0, 6.0, false)
	_add_light(props, "SocialCentreLamp", Vector2(161.5, 58.5), 3.0, Color(1, 0.9, 0.7), 1.0, 5.0)
	_add_light(props, "LaundretteSign", Vector2(57.6, 137.5), 2.6, Color(0.7, 0.85, 1.0), 0.9, 5.0)
	_add_light(props, "CarParkSign", Vector2(127, 98.5), 3.0, Color(0.95, 0.95, 1.0), 0.8, 4.0)
	_add_light(props, "TransformerLight", Vector2(100.5, 158.5), 2.4, Color(0.35, 1, 0.55), 0.8, 5.0)


# --- Facade dressing (T-045) ------------------------------------------------


## Lays the facade modules on the blocks of flats and on the upper mass of the
## tower. The visited storeys of the tower keep their real windows.
func _add_facade_dressing() -> void:
	var dressing: FacadeDressing = FACADE_DRESSING.new()
	dressing.name = "FacadeDressing"
	dressing.models.assign(FACADE_MODELS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971  # Fixed: the cité looks the same after every generation.
	var wall := 0
	for facade_name: String in FACADES:
		var rect: Rect2 = FACADES[facade_name][0]
		var storeys: int = FACADES[facade_name][1]
		var porch: Variant = FACADES[facade_name][2]
		for side in _sides(rect):
			_dress_wall(dressing, rng, wall, side, storeys, porch)
			wall += 1
	for side in _sides(TOWER):
		_dress_wall(dressing, rng, wall, side, TOWER_STOREYS, null, true)
		wall += 1
	_add(dressing)


## Shop fronts, the laundrette and its machines (T-046). The models only
## dress the greybox walls, which keep the collisions.
func _add_gallery_dressing() -> void:
	var node := _group("GalleryDressing")
	var r := GALLERY
	var width := r.size.x / GALLERY_SHOPS
	var front := r.position.y + GALLERY_ARCADE_DEPTH - WALL / 2 - FACADE_OFFSET
	var scenes := [SHOP_SHUTTER, LAUNDRETTE, SHOP_SHUTTER, SHOP_HALF, SHOP_SHUTTER]
	for i in GALLERY_SHOPS:
		var east := r.position.x + (i + 1) * width
		_place_model(node, scenes[i], "Shop%d" % (i + 1), Vector2(east, front), Vector2.UP)
	var laundrette := r.position.x + width
	var back := r.end.y - GALLERY_BACK_CORRIDOR
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		_place_model(node, WASHERS, "Washers%d" % (i + 1), Vector2(mx + 0.61, back - 1.0), Vector2.UP)


## Window frames, the entrance canopy and its sign, the tables (T-046).
func _add_social_centre_dressing() -> void:
	var node := _group("SocialCentreDressing")
	var r := SOCIAL_CENTRE
	var n := 0
	for x: float in [146.0, 152.0, 168.0, 174.0]:  # North wall, seen from the north.
		n += 1
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(x, r.position.y - FACADE_OFFSET), Vector2.UP)
	for x: float in [144.0, 152.0, 168.0]:  # South wall.
		n += 1
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(x, r.end.y + FACADE_OFFSET), Vector2.DOWN)
	for y: float in [65.5, 73.5, 81.5]:  # East wall: narrower windows.
		n += 1
		var narrow := Vector3(1.5 / CENTRE_WINDOW_WIDTH, 1, 1)
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(r.end.x + FACADE_OFFSET, y), Vector2.RIGHT, narrow)
	_place_model(node, CENTRE_ENTRANCE, "Entrance", Vector2(162.6, r.position.y - FACADE_OFFSET), Vector2.UP)
	var tables: Array = [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]
	for i in tables.size():
		_place_model(node, FOLDING_TABLE, "Table%d" % (i + 1), tables[i], Vector2.UP)
	for i in 3:  # Office desks, smaller.
		_place_model(node, FOLDING_TABLE, "Desk%d" % (i + 1), Vector2(172, 64 + 8 * i), Vector2.UP, Vector3(0.8, 1, 0.8))


## Wrecks, pillars, dead neons, the "P" sign and the garage doors (T-047).
func _add_car_park_dressing() -> void:
	var node := _group("CarParkDressing")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ceiling := -GROUND_THICKNESS
	for i in CAR_PARK_WRECKS.size():
		var turn := Vector2.UP if i % 2 == 0 else Vector2.DOWN
		_place_model(node, CAR_WRECK, "Wreck%d" % (i + 1), CAR_PARK_WRECKS[i], turn, Vector3.ONE, floor_h)
	var n := 0
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			n += 1
			_place_model(node, CAR_PARK_PILLAR, "Pillar%d" % n, Vector2(px, py), Vector2.UP, Vector3.ONE, floor_h)
		var neon := Vector2(px - CAR_PARK_PILLAR_STEP / 2.0, r.get_center().y)
		_place_model(node, NEON_FIXTURE, "Neon%d" % n, neon, Vector2.UP, Vector3.ONE, ceiling)
		px += CAR_PARK_PILLAR_STEP
	_place_model(node, CAR_PARK_SIGN, "SignP", Vector2(126.7, 99.5), Vector2.LEFT)
	# Garage doors on the east wall of the boxes, seen from the east.
	var g := GARAGES
	var width := g.size.y / GARAGE_COUNT
	for i in GARAGE_COUNT:
		var south := g.position.y + (i + 1) * width - 0.5
		var scene := GARAGE_OPEN if GARAGES_OPEN.has(i) else GARAGE_CLOSED
		_place_model(node, scene, "Garage%d" % (i + 1), Vector2(g.end.x + FACADE_OFFSET, south), Vector2.RIGHT)


## Transformer, playground and city stadium (T-048).
func _add_outdoor_dressing() -> void:
	var node := _group("OutdoorDressing")
	_place_model(node, TRANSFORMER, "Transformer", Vector2(100.5, 153.5), Vector2.UP)
	_place_model(node, SWING, "Swing", Vector2(61, 80.5), Vector2.UP)
	_place_model(node, CLIMBING_FRAME, "ClimbingFrame", Vector2(54.5, 74.5), Vector2.UP)
	_place_model(node, STADIUM_GOAL, "GoalWest", Vector2(149.5, 190), Vector2.RIGHT)
	_place_model(node, STADIUM_GOAL, "GoalEast", Vector2(176.5, 190), Vector2.LEFT)
	# Boards of the city stadium, facing out, around the openings (west, north).
	var runs := [
		[Vector2(160, 180), Vector2(148, 180), Vector2.UP],
		[Vector2(178, 180), Vector2(166, 180), Vector2.UP],
		[Vector2(148, 200), Vector2(178, 200), Vector2.DOWN],
		[Vector2(148, 180), Vector2(148, 188), Vector2.LEFT],
		[Vector2(148, 192), Vector2(148, 200), Vector2.LEFT],
		[Vector2(178, 200), Vector2(178, 180), Vector2.RIGHT],
	]
	# One MultiMesh per run: 45 separate boards would cost 90 draw calls.
	var boards: FacadeDressing = FACADE_DRESSING.new()
	boards.name = "StadiumBoards"
	boards.models.assign([STADIUM_BOARD])
	for r in runs.size():
		var from: Vector2 = runs[r][0]
		var to: Vector2 = runs[r][1]
		var normal: Vector2 = runs[r][2]
		var along := (to - from).normalized()
		var z_axis := Vector3(normal.x, 0, normal.y)
		var basis := Basis(Vector3.UP.cross(z_axis), Vector3.UP, z_axis)
		for i in roundi(from.distance_to(to) / STADIUM_BOARD_WIDTH):
			var at := from + along * (i * STADIUM_BOARD_WIDTH)
			boards.panels.append(Transform3D(basis, kit.world(at.x, at.y, 0.0)))
			boards.variants.append(0)
			boards.walls.append(r)
	node.add_child(boards)
	boards.owner = _root


## Wind everywhere, the motorway to the east, a train on the embankment now
## and then, the swing creaking (T-050). Plain players: none of them goes
## through NoiseBus, so they betray nobody.
func _add_ambience() -> void:
	var node := _group("Ambience")
	var wind := AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = WIND_SOUND
	wind.volume_db = -12.0
	wind.autoplay = true
	node.add_child(wind)
	wind.owner = _root
	for i in MOTORWAY_SOURCES.size():
		var road := _sound(node, "Motorway%d" % (i + 1), MOTORWAY_SOUND, Vector2(216, MOTORWAY_SOURCES[i]), 1.0)
		road.unit_size = 25.0
		road.max_distance = 150.0
		road.volume_db = -4.0
	var train: AudioStreamPlayer3D = AMBIENT_TRAIN.new()
	train.name = "Train"
	train.stream = TRAIN_SOUND
	train.unit_size = 40.0
	train.max_distance = 220.0
	train.track_start = kit.world(-40, 1, 7)
	train.track_end = kit.world(260, 1, 7)
	node.add_child(train)
	train.owner = _root
	var swing := _sound(node, "SwingCreak", SWING_SOUND, Vector2(61, 80.5), 2.0)
	swing.unit_size = 3.0
	swing.max_distance = 18.0


func _sound(parent: Node3D, node_name: String, stream: AudioStream, at: Vector2, h: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = stream
	player.autoplay = true
	player.position = kit.world(at.x, at.y, h)
	parent.add_child(player)
	player.owner = _root
	return player


func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_add(node)
	return node


## Instances a model at a plan point, its front (+Z) toward normal, its +X
## running along the wall as for the facade modules.
func _place_model(parent: Node3D, scene: PackedScene, node_name: String, at: Vector2, normal: Vector2, scale := Vector3.ONE, h := 0.0) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.name = node_name
	var z_axis := Vector3(normal.x, 0, normal.y)
	var x_axis := Vector3.UP.cross(z_axis)
	model.transform = Transform3D(Basis(x_axis * scale.x, Vector3.UP * scale.y, z_axis * scale.z), kit.world(at.x, at.y, h))
	parent.add_child(model)
	model.owner = _root
	return model


## The four outer walls of a rectangle, each as [start, end, outward normal] in
## plan coordinates, walked so that the module's +X runs from start to end.
func _sides(r: Rect2) -> Array:
	var nw := r.position
	var ne := Vector2(r.end.x, r.position.y)
	var se := r.end
	var sw := Vector2(r.position.x, r.end.y)
	return [
		[ne, nw, Vector2.UP],  # North: faces -y, walked east to west.
		[nw, sw, Vector2.LEFT],
		[sw, se, Vector2.DOWN],
		[se, ne, Vector2.RIGHT],
	]


func _dress_wall(
	dressing: FacadeDressing, rng: RandomNumberGenerator, wall: int, side: Array, storeys: int, porch: Variant, tower := false
) -> void:
	var start: Vector2 = side[0]
	var end: Vector2 = side[1]
	var normal: Vector2 = side[2]
	var length := start.distance_to(end)
	var count := maxi(1, roundi(length / MODULE_WIDTH))
	var width := length / count
	var along := (end - start).normalized()
	var x_axis := Vector3(along.x, 0, along.y) * (width / MODULE_WIDTH)
	var z_axis := Vector3(normal.x, 0, normal.y)
	var basis := Basis(x_axis, Vector3.UP, z_axis)
	var door_every := maxi(1, roundi(DOOR_SPACING / width))
	for column in count:
		var at := start + along * (column * width) + normal * FACADE_OFFSET
		var mid := start + along * ((column + 0.5) * width)
		var under_porch: bool = porch != null and mid.x > porch.x and mid.x < porch.y and absf(normal.y) > 0.5
		var balconies := rng.randf() < BALCONY_SHARE
		# The hall entrances of the tower stay open (north and south, ground floor).
		var entrance: bool = tower and absf(normal.y) > 0.5 and (mid.x > 103.0 and mid.x < 111.0 if normal.y < 0 else mid.x > 101.0 and mid.x < 109.0)
		for storey in storeys:
			if under_porch and storey * STOREY < PORCH_HEIGHT:
				continue
			if entrance and storey == 0:
				continue
			var module: int
			if tower and storey > 0 and storey < TOWER_VISITED_STOREYS:
				module = Module.OPEN
			elif storey == 0:
				var door := not tower and column % door_every == door_every / 2 and absf(normal.y) > 0.5
				module = Module.DOOR if door else (Module.WALLED if rng.randf() < WALLED_SHARE else Module.PLAIN)
			elif balconies:
				module = Module.BALCONY
			else:
				module = Module.LIT if rng.randf() < LIT_SHARE else Module.PLAIN
			var origin := kit.world(at.x, at.y) + Vector3.UP * (storey * STOREY)
			dressing.panels.append(Transform3D(basis, origin))
			dressing.variants.append(module)
			dressing.walls.append(wall)


## Instances a prop at a plan point, its local -Z (front) turned toward facing.
func _place(parent: Node3D, scene: PackedScene, node_name: String, at: Vector2, facing: Vector2) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	node.position = kit.world(at.x, at.y)
	node.rotation.y = atan2(-facing.x, -facing.y)
	return node


func _add_light(
	parent: Node3D, node_name: String, at: Vector2, height: float, color: Color,
	energy: float, light_range: float, fade := true
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_cull_mask = ~MapKit.BAKED_LAYER & 0xFFFFF
	light.distance_fade_enabled = fade
	light.distance_fade_begin = LIGHT_FADE_BEGIN
	light.distance_fade_length = LIGHT_FADE_LENGTH
	light.position = kit.world(at.x, at.y, height)
	parent.add_child(light)
	light.owner = _root
	return light


## Bakes the street lights and the landmark lights into the ground and the
## walls (T-049, plan B: no GPU for LightmapGI). Their real lights now only
## light the models, and fade out past LIGHT_FADE_BEGIN.
func _bake_light() -> void:
	var lights: Array[OmniLight3D] = []
	lights.assign(_root.get_node("Props").find_children("*", "OmniLight3D", true, false))
	var started := Time.get_ticks_msec()
	var space := _root.get_world_3d().direct_space_state
	var count := kit.bake_light(lights, space, MapKit.WORLD_LAYER | MapKit.WALLS_LAYER)
	print(
		"Baked %d lights in %d vertices in %d ms"
		% [lights.size(), count, Time.get_ticks_msec() - started]
	)


func _add_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	mesh.cell_size = 0.125
	# Lower than the monster (2.2 m): with cells 0.25 m high, a 2.4 m door
	# leaves less than 2.25 m of clearance on the voxel grid.
	mesh.agent_height = 2.0
	mesh.agent_radius = 0.375
	# Only inside the fences: no useless islands on the motorway or the wasteland.
	# The bottom sits just under a multiple of the cell height (0.25 m), so the
	# mesh lies about 0.26 m above floors at whole storeys: closer than the AI
	# agents' path_desired_distance (0.5 m), or they would never pass a path point.
	var lo := kit.world(FENCED.position.x, FENCED.position.y, NAV_BOTTOM)
	var hi := kit.world(FENCED.end.x, FENCED.end.y, 20)
	mesh.filter_baking_aabb = AABB(lo, hi - lo)
	region.navigation_mesh = mesh
	_root.add_child(region)
	region.owner = _root


func _add_gameplay() -> void:
	_root.set_script(MAP_SCRIPT)
	_add_loop()
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.fog_enabled = true
	env.environment = environment
	env.set_script(NIGHT_SCRIPT)
	_add(env)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.transform = Transform3D(Basis.from_euler(Vector3(-PI / 4, PI / 6, 0)), Vector3(0, 30, 0))
	_add(moon)
	env.set("moon", moon)
	var retro_world := Node.new()
	retro_world.name = "RetroWorld"
	retro_world.set_script(RETRO_WORLD_SCRIPT)
	_add(retro_world)
	_add(_named(RETRO_POST.instantiate(), "RetroPost"))
	var spawns := _markers("PlayerSpawns", PLAYER_SPAWNS)
	# Each hunted starts facing the tower, the landmark of the cité.
	var tower_center := kit.world(TOWER.get_center().x, TOWER.get_center().y)
	for marker: Node3D in spawns.get_children():
		var to := tower_center - marker.position
		marker.rotation.y = atan2(-to.x, -to.z)
	var monster_spawn := _markers("MonsterSpawn", [MONSTER_SPAWN])
	var patrol := _markers("PatrolRoute", PATROL_ROUTE)
	_markers("PreyRoute", PREY_ROUTE)
	_markers("HidingSpots", HIDING_SPOTS)
	_markers("GuardPoints", GUARD_POINTS)
	var monster: Node3D = _named(MONSTER.instantiate(), "Monster")
	monster.position = monster_spawn.get_child(0).position
	monster.set("patrol_route", patrol)
	monster.set("start_index", 0)
	_add(monster)
	_add(_named(NOISE_DEBUG.instantiate(), "NoiseDebug"))
	var player: Node3D = _named(PLAYER.instantiate(), "Player")
	player.transform = spawns.get_child(0).transform
	_add(player)
	var overlay := _named(OVERLAY.instantiate(), "DebugOverlay")
	overlay.set("player", player)
	overlay.set("monster", monster)
	_add(overlay)
	var gauge := _named(GAUGE.instantiate(), "NoiseGauge")
	gauge.set("player", player)
	_add(gauge)
	var prompt := _named(INTERACT_PROMPT.instantiate(), "InteractPrompt")
	prompt.set("player", player)
	_add(prompt)
	_add(_named(CAUGHT.instantiate(), "CaughtScreen"))


## Patrol of the AI monster, as plan points (x, height, y): every street and
## the inside of each scannable building, from its corner (T-041).
const PATROL_ROUTE := [
	Vector3(190, 0, 190), Vector3(200, 0, 125), Vector3(160, -3, 106), Vector3(150, 0, 122),
	Vector3(161.5, 0, 72), Vector3(155, 0, 45), Vector3(104, 0, 92), Vector3(108, 12, 100),
	Vector3(66, 0, 137), Vector3(84, 0, 148), Vector3(40, 0, 150), Vector3(14, 0, 158.5),
	Vector3(40, 0, 120), Vector3(61, 0, 81), Vector3(40, 0, 52), Vector3(100, 0, 52),
	Vector3(120, 0, 140), Vector3(163, 0, 190),
]
## Where the AI monster walks to and fro once the exit is open (S-007, Q4):
## the south mouth of the tunnel and both sides of it.
const GUARD_POINTS := [Vector3(155, 0, 14), Vector3(146, 0, 20), Vector3(164, 0, 20)]
## Wander points of the AI prey (monster role), outside and inside.
const PREY_ROUTE := [
	Vector3(45, 0, 44), Vector3(95, 0, 52), Vector3(155, 0, 40), Vector3(124, 0, 96),
	Vector3(96, 6, 100), Vector3(105, 0, 140), Vector3(61, 0, 80), Vector3(40, 0, 150),
	Vector3(56, 0, 143), Vector3(72, 0, 112), Vector3(150, 0, 72), Vector3(160, -3, 110),
]
## Hiding spots of the AI prey: in the lee of a block, or inside a building.
const HIDING_SPOTS := [
	Vector3(29, 0, 95), Vector3(88, 0, 36), Vector3(183, 0, 80), Vector3(139, 0, 180),
	Vector3(98, 0, 159), Vector3(70, 0, 208), Vector3(95, 9, 109), Vector3(160, -3, 111),
	Vector3(13, 0, 176), Vector3(54.5, 0, 145.5),
]


func _markers(node_name: String, points: Array) -> Node3D:
	var parent := Node3D.new()
	parent.name = node_name
	_add(parent)
	for i in points.size():
		var marker := Marker3D.new()
		marker.name = "Point%d" % (i + 1)
		var at: Variant = points[i]
		if at is Vector3:
			marker.position = kit.world(at.x, at.z, at.y)
		else:
			marker.position = kit.world(at.x, at.y)
		parent.add_child(marker)
		marker.owner = _root
	return parent


func _add(node: Node) -> void:
	_root.add_child(node)
	node.owner = _root


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


## Plain colored materials of the greybox, made once and shared.
func _material(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	match key:
		"grille":
			material.albedo_color = Color(0.16, 0.17, 0.18)
		"fence":
			material.albedo_color = Color(0.32, 0.33, 0.3)
		"metal":
			material.albedo_color = Color(0.38, 0.4, 0.42)
			material.roughness = 0.6
		"transformer":
			material.albedo_color = Color(0.2, 0.36, 0.26)
		"garage_door":
			material.albedo_color = Color(0.3, 0.32, 0.36)
			material.roughness = 0.6
		"beacon":
			_glow(material, Color(1, 0.12, 0.08))
		"sign_warm":
			_glow(material, Color(0.95, 0.88, 0.7))
		"sign_cold":
			_glow(material, Color(0.7, 0.85, 1.0))
		"sign_white":
			_glow(material, Color(0.92, 0.94, 1.0))
	_materials[key] = material
	return material


## A sign or a beacon: lit by itself, never orange (constitution 2.3).
func _glow(material: StandardMaterial3D, color: Color) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
