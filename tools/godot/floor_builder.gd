extends RefCounted
## The floors of the cité des Tilleuls (spec S-012, T-143): the SurfaceMap the
## footsteps read, and the puddles. Called by build_tilleuls.gd.
##   - each lined room (kit.zones, S-019) gives its floor tile,
##   - the paths and the car park ramp are asphalt (concrete),
##   - the inside of each visitable building is concrete where no room says
##     otherwise, the open ground is the dead lawn (SurfaceMap.ground_kind),
##   - the puddles: outdoor ones on the paths, and the car park's (lining).

const InteriorLining := preload("res://tools/godot/interior_lining.gd")
const SURFACES_PATH := "res://game/maps/tilleuls/tilleuls_surfaces.tres"
const PUDDLE_COUNT := 12
const PUDDLE_SEED := 1212
const PUDDLE_SEGMENTS := 12
## Radii of an outdoor puddle (long and short), in meters.
const PUDDLE_RADII := Vector2(1.2, 0.7)
## How far from the middle of a path a puddle may lie, in meters.
const PUDDLE_SIDE := 1.2
## A floor box reaches this far below the floor and above it, in meters: the
## feet and the noise (0.3 m up) both fall inside.
const BELOW := 0.3
const ABOVE := 1.0
const PUDDLE_COLOR := Color(0.035, 0.04, 0.05)

## Atlas floor tiles (InteriorLining.Tile) and their floors.
const TILE_FLOORS := {
	"TERRAZZO": FloorSurface.Kind.TILE,
	"LINO": FloorSurface.Kind.TILE,
	"WARD_LINO": FloorSurface.Kind.TILE,
	"WARD_CORRIDOR": FloorSurface.Kind.TILE,
	"FAIENCE": FloorSurface.Kind.TILE,
	"PARQUET": FloorSurface.Kind.WOOD,
	"CONCRETE": FloorSurface.Kind.CONCRETE,
}

## Outdoor puddles, as plan rectangles at ground level (filled by add_puddles).
var puddles: Array[Rect2] = []

var _builder: Object
var _kit: RefCounted


func _init(builder: Object, kit: RefCounted) -> void:
	_builder = builder
	_kit = kit


## Picks the outdoor puddles on the paths, away from every building, and
## adds their mesh under parent.
func add_puddles(parent: Node3D, owner: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PUDDLE_SEED
	var paths: Array = _builder.PATHS
	var segments: Array = []
	for line: Array in paths:
		for i in line.size() - 1:
			segments.append([line[i], line[i + 1]])
	var tries := 0
	while puddles.size() < PUDDLE_COUNT and tries < 500:
		tries += 1
		var seg: Array = segments[rng.randi_range(0, segments.size() - 1)]
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var at := a.lerp(b, rng.randf_range(0.1, 0.9)) + side * rng.randf_range(-PUDDLE_SIDE, PUDDLE_SIDE)
		var half := Vector2(PUDDLE_RADII.x, PUDDLE_RADII.y) if absf(along.x) > 0.5 else Vector2(PUDDLE_RADII.y, PUDDLE_RADII.x)
		var rect := Rect2(at - half, half * 2.0)
		if _blocked(rect.grow(1.0)) or _near_puddle(rect.grow(4.0)):
			continue
		puddles.append(rect)
	var mesh := _puddle_mesh(rng)
	var node := MeshInstance3D.new()
	node.name = "Puddles"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.owner = owner


## The SurfaceMap of the whole map, saved to SURFACES_PATH and returned.
func save_surfaces(car_park_puddles: Array[AABB]) -> SurfaceMap:
	var map := SurfaceMap.new()
	var tile_names: Array = InteriorLining.Tile.keys()
	for z in _kit.zones:
		if z.floor < 0:
			continue
		var kind: int = TILE_FLOORS.get(tile_names[z.floor], FloorSurface.Kind.CONCRETE)
		map.add(_grown(z.box), kind)
	var h: float = _builder.PATH_HEIGHT
	var half: float = _builder.PATH_WIDTH / 2.0
	for line: Array in _builder.PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half
			map.add(_flat(Rect2(lo, hi - lo), 0.0, h), FloorSurface.Kind.CONCRETE)
	map.add(_flat(_builder.CAR_PARK_RAMP, -3.0, 0.0), FloorSurface.Kind.CONCRETE)
	map.add(_flat(Rect2(211, 10, 9, 210), 0.0, h), FloorSurface.Kind.CONCRETE)
	map.add(_flat(Rect2(0, 213, 211, 7), 0.0, h), FloorSurface.Kind.CONCRETE)
	var buildings: Dictionary = _builder.call("_buildings")
	var extras: Dictionary = _builder.call("_extra_boxes")
	for building_name: String in buildings:
		var entry: Array = buildings[building_name]
		map.add(_flat(entry[0], entry[1], entry[2] - ABOVE), FloorSurface.Kind.CONCRETE)
		for extra: Array in extras.get(building_name, []):
			map.add(_flat(extra[0], extra[1], extra[2] - ABOVE), FloorSurface.Kind.CONCRETE)
	for rect in puddles:
		map.add(_flat(rect, 0.0, h), FloorSurface.Kind.PUDDLE)
	for box in car_park_puddles:
		var tall := AABB(box.position - Vector3(0, BELOW, 0), box.size + Vector3(0, BELOW + ABOVE, 0))
		map.add(tall, FloorSurface.Kind.PUDDLE)
	map.sort()
	var error := ResourceSaver.save(map, SURFACES_PATH)
	map.take_over_path(SURFACES_PATH)
	print("Saved %s (%d boxes), error %d" % [SURFACES_PATH, map.boxes.size(), error])
	return map


## A world box over a plan rectangle, for a floor from h0 to h1.
func _flat(rect: Rect2, h0: float, h1: float) -> AABB:
	var lo: Vector3 = _kit.world(rect.position.x, rect.position.y, h0 - BELOW)
	return AABB(lo, Vector3(rect.size.x, h1 - h0 + BELOW + ABOVE, rect.size.y))


func _grown(box: AABB) -> AABB:
	return AABB(box.position - Vector3(0, BELOW, 0), box.size + Vector3(0, BELOW, 0))


func _blocked(rect: Rect2) -> bool:
	var buildings: Dictionary = _builder.call("_buildings")
	for building_name: String in buildings:
		if (buildings[building_name][0] as Rect2).intersects(rect):
			return true
	var facades: Dictionary = _builder.FACADES
	for block: String in facades:
		if (facades[block][0] as Rect2).intersects(rect):
			return true
	return false


func _near_puddle(rect: Rect2) -> bool:
	for other in puddles:
		if other.intersects(rect):
			return true
	return false


## One mesh for every outdoor puddle: an irregular dark pool, just above the
## asphalt. One draw call in all.
func _puddle_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var y: float = _builder.PATH_HEIGHT + 0.006
	for rect in puddles:
		var c := rect.get_center()
		var r := rect.size / 2.0
		var ring: Array[Vector3] = []
		for i in PUDDLE_SEGMENTS:
			var angle := TAU * i / PUDDLE_SEGMENTS
			var wobble := rng.randf_range(0.75, 1.0)
			ring.append(_kit.world(c.x + cos(angle) * r.x * wobble, c.y + sin(angle) * r.y * wobble, y))
		var center: Vector3 = _kit.world(c.x, c.y, y)
		for i in PUDDLE_SEGMENTS:
			st.add_vertex(center)
			st.add_vertex(ring[(i + 1) % PUDDLE_SEGMENTS])
			st.add_vertex(ring[i])
	var material := StandardMaterial3D.new()
	material.albedo_color = PUDDLE_COLOR
	material.roughness = 0.08
	material.metallic_specular = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)
	return st.commit()
