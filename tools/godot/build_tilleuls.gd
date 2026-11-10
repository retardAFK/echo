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
const PATH_WIDTH := 5.0
const PATH_HEIGHT := 0.02
## One storey of a block of flats, in meters.
const STOREY := 3.0

const MAT_DIRT := preload("res://game/fx/materials/ground_dirt.tres")
const MAT_ASPHALT := preload("res://game/fx/materials/asphalt_floor.tres")
const MAT_CONCRETE := preload("res://game/fx/materials/concrete_wall.tres")
const MAT_OBSTACLE := preload("res://game/fx/materials/concrete_obstacle.tres")

const PLAYER := preload("res://game/entities/player/player.tscn")
const MONSTER := preload("res://game/entities/monster/monster.tscn")
const OVERLAY := preload("res://game/ui/debug_overlay.tscn")
const NOISE_DEBUG := preload("res://game/ui/noise_debug.tscn")
const GAUGE := preload("res://game/ui/noise_gauge.tscn")
const CAUGHT := preload("res://game/ui/caught_screen.tscn")
const RETRO_POST := preload("res://game/fx/retro_post.tscn")
const LAMPPOST := preload("res://game/entities/props/lamppost.tscn")
const BENCH_DIRTY := preload("res://game/entities/props/bench_dirty.tscn")
const BENCH_BROKEN := preload("res://game/entities/props/bench_broken.tscn")
const TREE_BARE := preload("res://game/entities/props/tree_bare.tscn")
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

## Blocks of flats seen from outside only (plan A to G): rectangle and storeys.
const FACADES := {
	"BarreA": [Rect2(15, 22, 70, 12), 5],
	"BarreC": [Rect2(15, 60, 12, 70), 5],
	"BarreD": [Rect2(185, 55, 12, 55), 5],
	"BarreE": [Rect2(45, 192, 55, 12), 5],
	"BarreF": [Rect2(125, 160, 12, 40), 4],
	"BarreG": [Rect2(150, 145, 45, 10), 4],
}

## Where the hunted may start, far from the monster (Q2).
const PLAYER_SPAWNS := [
	Vector2(45, 44), Vector2(95, 44), Vector2(32, 150), Vector2(72, 112),
	Vector2(128, 98), Vector2(170, 44),
]
const MONSTER_SPAWN := Vector2(190, 190)

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
	[Vector2(203, 180), Vector2.LEFT], [Vector2(64, 74), Vector2.DOWN],
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
	kit.build(_root)
	_add_props()
	_add_navigation()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
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
	var holes: Array[Rect2] = []
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
	kit.box(tunnel, 150, 2.8, 160, 3.2, 0, 3.6, _material("grille"))
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
		var s := kit.structure(facade_name)
		kit.box(s, rect.position.x, rect.position.y, rect.end.x, rect.end.y, 0, height, MAT_CONCRETE)
	# Barre B: the path to the exit goes under a porch through it.
	var b := kit.structure("BarreB")
	var top := 5 * STOREY
	kit.box(b, 125, 22, 150, 34, 0, top, MAT_CONCRETE)
	kit.box(b, 160, 22, 195, 34, 0, top, MAT_CONCRETE)
	kit.box(b, 150, 22, 160, 34, 4, top, MAT_CONCRETE, MapKit.Kind.FLOOR)


# --- Outdoor landmarks ------------------------------------------------------


func _build_landmarks() -> void:
	_build_playground()
	_build_city_stadium()
	var transformer := kit.structure("Transformer")
	kit.box(transformer, 96, 150, 105, 157, 0, 2.6, _material("transformer"))
	kit.box(transformer, 95.5, 149.5, 105.5, 157.5, 2.6, 2.8, MAT_OBSTACLE, MapKit.Kind.GHOST)


func _build_playground() -> void:
	var s := kit.structure("Playground")
	var low := MapKit.Kind.FLOOR
	# Kerb around the sand.
	kit.box(s, 50, 70, 72, 70.3, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 50, 91.7, 72, 92, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 50, 70.3, 50.3, 91.7, 0, 0.25, MAT_OBSTACLE, low)
	kit.box(s, 71.7, 70.3, 72, 91.7, 0, 0.25, MAT_OBSTACLE, low)
	# Swing: two posts at each end, a top bar, two seats on their chains.
	var metal := _material("metal")
	for x: float in [57.0, 65.0]:
		kit.box(s, x - 0.1, 79.0, x + 0.1, 79.2, 0, 2.4, metal, low)
		kit.box(s, x - 0.1, 81.8, x + 0.1, 82.0, 0, 2.4, metal, low)
	kit.box(s, 56.9, 80.4, 65.1, 80.6, 2.3, 2.5, metal, MapKit.Kind.GHOST)
	for x: float in [59.5, 62.5]:
		kit.box(s, x - 0.3, 80.3, x + 0.3, 80.7, 0.45, 0.5, metal, MapKit.Kind.GHOST)
		kit.box(s, x - 0.28, 80.48, x - 0.26, 80.52, 0.5, 2.3, metal, MapKit.Kind.GHOST)
		kit.box(s, x + 0.26, 80.48, x + 0.28, 80.52, 0.5, 2.3, metal, MapKit.Kind.GHOST)
	# Climbing frame and slide.
	kit.box(s, 53, 73, 56, 76, 0, 1.6, metal, low)
	kit.ramp(s, 56, 74, 59.5, 75, 1.6, 0.2, true, metal, 0.1)


func _build_city_stadium() -> void:
	var s := kit.structure("CityStadium")
	var boards := _material("metal")
	var h := 1.1
	# Boards with an opening on the west and the north sides.
	kit.wall_x(s, 148, 178, 180, 0, h, 0.15, boards, [[160, 166, 0]])
	kit.wall_x(s, 148, 178, 200, 0, h, 0.15, boards)
	kit.wall_y(s, 180, 200, 148, 0, h, 0.15, boards, [[188, 192, 0]])
	kit.wall_y(s, 180, 200, 178, 0, h, 0.15, boards)
	# Goals at both ends.
	for x: float in [149.5, 176.5]:
		kit.box(s, x - 0.06, 188.5, x + 0.06, 188.62, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 191.38, x + 0.06, 191.5, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 188.5, x + 0.06, 191.5, 1.9, 2, boards, MapKit.Kind.GHOST)


# --- Props, lights and gameplay nodes ---------------------------------------


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
	_add_light(props, "TransformerLight", Vector2(100.5, 158.5), 2.4, Color(0.35, 1, 0.55), 0.8, 5.0)


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
	energy: float, light_range: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = kit.world(at.x, at.y, height)
	parent.add_child(light)
	light.owner = _root
	return light


func _add_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	mesh.cell_size = 0.125
	mesh.agent_height = 2.25
	mesh.agent_radius = 0.375
	# Only inside the fences: no useless islands on the motorway or the wasteland.
	var lo := kit.world(FENCED.position.x, FENCED.position.y, -5)
	var hi := kit.world(FENCED.end.x, FENCED.end.y, 20)
	mesh.filter_baking_aabb = AABB(lo, hi - lo)
	region.navigation_mesh = mesh
	_root.add_child(region)
	region.owner = _root


func _add_gameplay() -> void:
	_root.set_script(MAP_SCRIPT)
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
	var monster_spawn := _markers("MonsterSpawn", [MONSTER_SPAWN])
	var patrol := _markers("PatrolRoute", PATROL_ROUTE)
	_markers("PreyRoute", PREY_ROUTE)
	_markers("HidingSpots", HIDING_SPOTS)
	var monster: Node3D = _named(MONSTER.instantiate(), "Monster")
	monster.position = monster_spawn.get_child(0).position
	monster.set("patrol_route", patrol)
	monster.set("start_index", 0)
	_add(monster)
	_add(_named(NOISE_DEBUG.instantiate(), "NoiseDebug"))
	var player: Node3D = _named(PLAYER.instantiate(), "Player")
	player.position = spawns.get_child(0).position
	_add(player)
	var overlay := _named(OVERLAY.instantiate(), "DebugOverlay")
	overlay.set("player", player)
	overlay.set("monster", monster)
	_add(overlay)
	var gauge := _named(GAUGE.instantiate(), "NoiseGauge")
	gauge.set("player", player)
	_add(gauge)
	_add(_named(CAUGHT.instantiate(), "CaughtScreen"))


## Patrol of the AI monster: the main streets, from its corner (T-041 adds the
## inside of the buildings).
const PATROL_ROUTE := [
	Vector2(190, 190), Vector2(200, 122), Vector2(150, 122), Vector2(105, 130),
	Vector2(105, 185), Vector2(40, 185), Vector2(40, 120), Vector2(40, 52),
	Vector2(100, 52), Vector2(155, 45), Vector2(160, 90), Vector2(200, 130),
]
## Wander points of the AI prey (monster role).
const PREY_ROUTE := [
	Vector2(45, 44), Vector2(95, 52), Vector2(155, 40), Vector2(128, 98),
	Vector2(105, 140), Vector2(61, 80), Vector2(40, 150), Vector2(72, 112),
]
## Hiding spots of the AI prey: in the lee of a block or a landmark.
const HIDING_SPOTS := [
	Vector2(29, 95), Vector2(88, 36), Vector2(183, 80), Vector2(139, 180),
	Vector2(98, 159), Vector2(70, 206),
]


func _markers(node_name: String, points: Array) -> Node3D:
	var parent := Node3D.new()
	parent.name = node_name
	_add(parent)
	for i in points.size():
		var marker := Marker3D.new()
		marker.name = "Point%d" % (i + 1)
		marker.position = kit.world(points[i].x, points[i].y)
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
	_materials[key] = material
	return material
