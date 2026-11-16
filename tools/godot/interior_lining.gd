extends RefCounted
## Interiors of the cité des Tilleuls with the mood of the hospital (S-019,
## mood board tools/blender/hlm_interior_mood.py, validated by Maxime on
## 15/11/2026): flats that were lived in, then left in a hurry.
##
## Lines the rooms of the tower, the cellars, the social centre, the gallery
## and the car park with the interior atlas
## (assets/textures/interior_atlas.png, tools/godot/make_interior_atlas.gd):
## the walls, floors and ceilings keep their blocks, collisions and navigation;
## only the faces looking into a room change look, all in one material, so the
## whole lining costs one draw call per structure.
##
## Called from build_tilleuls.gd with the builder, whose constants give the plan.

const MapKit := preload("res://tools/godot/map_kit.gd")
const LINING := preload("res://game/fx/materials/interior_lining.tres")
const MAT_CONCRETE := preload("res://game/fx/materials/concrete_wall.tres")
const MAT_OBSTACLE := preload("res://game/fx/materials/concrete_obstacle.tres")
const DECOR := preload("res://game/fx/materials/interior_decor.tres")
## The decor of a storey is drawn within this distance of its center.
const DECOR_DISTANCE := 14.0
## Lamps: caged hublots and tubes, mostly dead; the live ones light the walls
## (baked) and the furniture and players near them (real light, faded out).
const LAMP_COLOR := Color(0.75, 1.0, 0.85)
const TUBE_COLOR := Color(0.55, 1.0, 0.7)
const BULB_COLOR := Color(1.0, 0.92, 0.75)
const TV_COLOR := Color(0.55, 0.65, 1.0)
const EXIT_COLOR := Color(0.4, 1.0, 0.55)
const DEAD_GLASS := Color(0.33, 0.34, 0.32)
const DARK := Color(0.04, 0.04, 0.045)
const PAPER := Color(0.55, 0.55, 0.5)
const WOOD := Color(0.24, 0.15, 0.1)
const BRASS := Color(0.36, 0.3, 0.15)
const STEEL := Color(0.42, 0.44, 0.44)
const MAT_BROWN := Color(0.2, 0.15, 0.1)
## Front doors of the flats, as in build_tilleuls.gd _tower_flats: west edge x
## of the doorway and whether it opens on the north wall of the corridor.
const FRONT_DOORS := [[97.0, true], [108.0, true], [98.5, false], [106.0, false]]
## Corridor lamps along each storey (plan x), and the one still alive per storey.
const CORRIDOR_LAMPS := [94.5, 98.0, 108.5, 113.0]
## Tables of the east flats (FLAT_FURNITURE): a TV left on, on some storeys.
const TV_TABLES := [[Vector2(108.3, 92.5), [2, 4]], [Vector2(109.6, 104.2), [1, 2, 3, 4]]]
const TABLE_TOP := 0.76
## Dead bulbs along the cellar corridor (plan x), and the ones still alive.
const CELLAR_BULBS := [96.0, 104.0, 112.0, 120.0, 128.0, 136.0]
const CELLAR_BULBS_ALIVE := [104.0, 128.0]
## Seven-segment digits painted in the stairwell: a b c d e f g.
const DIGITS := {
	1: [false, true, true, false, false, false, false],
	2: [true, true, false, true, true, false, true],
	3: [true, true, true, true, false, false, true],
	4: [false, true, true, false, false, true, true],
	5: [true, false, true, true, false, true, true],
}

## A wall shows its tile up to this height above its floor (one storey of the
## tower); higher up, in the taller rooms of the social centre and the gallery,
## it is the stained plaster of the ceiling.
const TILE_HEIGHT := 3.0
## The social centre, the gallery and the car park are wider than a storey of
## the tower: their decor is drawn from a little farther.
const WIDE_DECOR_DISTANCE := 18.0
## Shops of the gallery, west to east: wall and floor tiles.
const SHOP_TILES := [
	["HALL", "LINO"],
	["KITCHEN", "LINO"],
	["LIVING", "PARQUET"],
	["STAIRS", "LINO"],
	["KITCHEN", "LINO"],
]
## Tubes of the car park (plan x, y): the live ones light the wrecks.
const CAR_PARK_TUBES := [
	Vector2(144, 99),
	Vector2(152, 99),
	Vector2(160, 99),
	Vector2(168, 99),
	Vector2(144, 106),
	Vector2(152, 106),
	Vector2(160, 106),
	Vector2(168, 106),
	Vector2(144, 113),
	Vector2(152, 113),
	Vector2(160, 113),
	Vector2(168, 113),
]
const CAR_PARK_TUBES_ALIVE := [Vector2(152, 99), Vector2(160, 113)]
## Paper bunting across the great hall: no orange (constitution 2.3).
const BUNTING := [
	Color(0.45, 0.1, 0.1), Color(0.12, 0.2, 0.42), Color(0.42, 0.4, 0.12), Color(0.12, 0.32, 0.18)
]

## Atlas tiles, in the order of make_interior_atlas.gd.
enum Tile {
	HALL,
	STAIRS,
	CORRIDOR,
	LIVING,
	BEDROOM,
	KITCHEN,
	CELLAR,
	CEILING,
	TERRAZZO,
	LINO,
	PARQUET,
	CONCRETE,
}

var _constants: Dictionary
var _kit: RefCounted
var _rng := RandomNumberGenerator.new()
var _decor: SurfaceTool
## Origin of the decor mesh being built: its node stands there, so the
## distance it is drawn from is measured from the middle of its storey.
var _offset := Vector3.ZERO


func _init(builder: Object) -> void:
	_constants = builder.get_script().get_script_constant_map()


func _c(key: String) -> Variant:
	return _constants[key]


## Adds the lined rooms to the kit. Call before kit.build().
func add_zones(kit: RefCounted) -> void:
	_kit = kit
	kit.lining = LINING
	kit.lined_materials.assign([MAT_CONCRETE, MAT_OBSTACLE])
	_tower(kit)
	_cellars(kit)
	_social_centre(kit)
	_gallery(kit)
	_car_park(kit)


func _tower(kit: RefCounted) -> void:
	var r: Rect2 = _c("TOWER")
	var storey: float = _c("STOREY")
	var storeys: int = _c("TOWER_VISITED_STOREYS")
	var corridor: Vector2 = _c("CORRIDOR")
	var stair_x: float = _c("STAIR_X")
	var stair_east: float = stair_x + 2 * _c("STAIR_FLIGHT_WIDTH") + _c("STAIR_DIVIDER")
	var landing: float = _c("STAIR_LANDING_Y")
	var stair_north: float = landing - _c("STAIR_FLIGHT_LENGTH") - _c("STAIR_MID_LANDING")
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	# The stairwell, from the ground to the top: first, so it wins.
	var stairs := Rect2(stair_x, stair_north, stair_east - stair_x, landing - stair_north)
	kit.zone(stairs, 0.0, storeys * storey, Tile.STAIRS, Tile.TERRAZZO, Tile.CEILING)
	# Ground floor: the cellar stairs room and the bin room, then the hall.
	kit.zone(_rect(x0, y0, 99.0, landing), 0.0, storey, Tile.CELLAR, Tile.CONCRETE, Tile.CEILING)
	kit.zone(_rect(x0, 104.0, 99.0, y1), 0.0, storey, Tile.CELLAR, Tile.CONCRETE, Tile.CEILING)
	kit.zone(r, 0.0, storey, Tile.HALL, Tile.TERRAZZO, Tile.CEILING)
	# The storeys: the corridor, then the rooms of the four flats.
	for level in range(1, storeys):
		var h: float = level * storey
		var top := h + storey
		kit.zone(
			_rect(x0, corridor.x, x1, corridor.y), h, top, Tile.CORRIDOR, Tile.LINO, Tile.CEILING
		)
		var rooms := [
			# North-west and north-east flats: a bedroom, then the living room.
			[_rect(x0, y0, 96.0, corridor.x), Tile.BEDROOM, Tile.PARQUET],
			[_rect(96.0, y0, stair_x, corridor.x), Tile.LIVING, Tile.PARQUET],
			[_rect(stair_east, y0, 111.0, corridor.x), Tile.LIVING, Tile.PARQUET],
			[_rect(111.0, y0, x1, corridor.x), Tile.BEDROOM, Tile.PARQUET],
			# South flats: the living room, then the kitchen on the outer side
			# and the bedroom (with the bed of FLAT_FURNITURE).
			[_rect(x0, corridor.y, 104.0, 107.0), Tile.LIVING, Tile.PARQUET],
			[_rect(x0, 107.0, 98.0, y1), Tile.KITCHEN, Tile.LINO],
			[_rect(98.0, 107.0, 104.0, y1), Tile.BEDROOM, Tile.PARQUET],
			[_rect(104.0, corridor.y, x1, 107.0), Tile.LIVING, Tile.PARQUET],
			[_rect(104.0, 107.0, 110.0, y1), Tile.BEDROOM, Tile.PARQUET],
			[_rect(110.0, 107.0, x1, y1), Tile.KITCHEN, Tile.LINO],
		]
		for room: Array in rooms:
			kit.zone(room[0], h, top, room[1], room[2], Tile.CEILING)


func _cellars(kit: RefCounted) -> void:
	var corridor: Rect2 = _c("CELLAR_CORRIDOR")
	var cages: Vector2 = _c("CELLAR_CAGES")
	var depth: float = _c("CAR_PARK_DEPTH")
	var cage_depth: float = _c("CELLAR_CAGE_DEPTH")
	var ceiling: float = -_c("GROUND_THICKNESS")
	kit.zone(corridor, -depth, ceiling, Tile.CELLAR, Tile.CONCRETE, Tile.CEILING)
	var alcove := _rect(cages.x, corridor.position.y - cage_depth, cages.y, corridor.position.y)
	kit.zone(alcove, -depth, ceiling, Tile.CELLAR, Tile.CONCRETE, Tile.CEILING)


## A room taller than a storey: its tile up to TILE_HEIGHT, plaster above.
func _tall_zone(
	kit: RefCounted, rect: Rect2, h0: float, h1: float, wall: int, floor_tile: int
) -> void:
	kit.zone(rect, h0, h0 + TILE_HEIGHT, wall, floor_tile, Tile.CEILING)
	if h1 > h0 + TILE_HEIGHT:
		kit.zone(rect, h0 + TILE_HEIGHT, h1, Tile.CEILING, floor_tile, Tile.CEILING)


## The rooms on the ground stand on the street's slab: a thin floor without
## collision in their structure takes their floor tile, as on the ground floor
## of the tower.
func _ground_floor(kit: RefCounted, structure: String, rect: Rect2) -> void:
	for s: MapKit.Structure in kit.structures:
		if s.name == structure:
			kit.box(
				s,
				rect.position.x,
				rect.position.y,
				rect.end.x,
				rect.end.y,
				0.0,
				0.03,
				MAT_OBSTACLE,
				MapKit.Kind.GHOST
			)
			return
	push_error("No structure %s to floor" % structure)


## The social centre: the great hall, its kitchen, the corridor, three offices.
func _social_centre(kit: RefCounted) -> void:
	var r: Rect2 = _c("SOCIAL_CENTRE")
	var h: float = _c("SOCIAL_CENTRE_HEIGHT")
	_ground_floor(kit, "SocialCentre", r.grow(-_c("WALL")))
	_tall_zone(kit, _c("CENTRE_KITCHEN"), 0.0, h, Tile.KITCHEN, Tile.LINO)
	_tall_zone(
		kit, _rect(r.position.x, r.position.y, 160.0, r.end.y), 0.0, h, Tile.STAIRS, Tile.PARQUET
	)
	_tall_zone(kit, _rect(160.0, r.position.y, 163.0, r.end.y), 0.0, h, Tile.CORRIDOR, Tile.LINO)
	var offices := [
		[r.position.y, 68.0, Tile.LIVING], [68.0, 76.0, Tile.BEDROOM], [76.0, r.end.y, Tile.STAIRS]
	]
	for office: Array in offices:
		_tall_zone(kit, _rect(163.0, office[0], r.end.x, office[1]), 0.0, h, office[2], Tile.LINO)


## The shops of the gallery and the delivery corridor behind them; the arcade
## stays bare concrete.
func _gallery(kit: RefCounted) -> void:
	var r: Rect2 = _c("GALLERY")
	var h: float = _c("GALLERY_HEIGHT")
	var front: float = r.position.y + _c("GALLERY_ARCADE_DEPTH")
	var back: float = r.end.y - _c("GALLERY_BACK_CORRIDOR")
	var width: float = r.size.x / SHOP_TILES.size()
	var wall: float = _c("WALL")
	_ground_floor(kit, "Gallery", _rect(r.position.x + wall, front, r.end.x - wall, r.end.y - wall))
	for i in SHOP_TILES.size():
		var tiles: Array = SHOP_TILES[i]
		var x := r.position.x + i * width
		_tall_zone(kit, _rect(x, front, x + width, back), 0.0, h, Tile[tiles[0]], Tile[tiles[1]])
	_tall_zone(kit, _rect(r.position.x, back, r.end.x, r.end.y), 0.0, h, Tile.CELLAR, Tile.CONCRETE)


## The car park keeps its asphalt; its walls and pillars get the painted,
## tagged concrete of the cellars.
func _car_park(kit: RefCounted) -> void:
	var ceiling: float = -_c("GROUND_THICKNESS")
	kit.zone(
		_c("CAR_PARK"), -_c("CAR_PARK_DEPTH"), ceiling, Tile.CELLAR, Tile.CONCRETE, Tile.CEILING
	)


# --- Decor and lamps ------------------------------------------------------------


## Dresses the tower and the cellars under root: one decor mesh per storey
## (one draw call: painted boxes, and glowing ones), drawn near it only, and
## the live lamps under Props, so the map bakes them like the street lights.
## Call after kit.build() and before the light is baked.
func dress(root: Node3D) -> void:
	_rng.seed = 19
	var node := Node3D.new()
	node.name = "InteriorDecor"
	root.add_child(node)
	node.owner = root
	var lights := Node3D.new()
	lights.name = "InteriorLights"
	root.get_node("Props").add_child(lights)
	lights.owner = root
	var storey: float = _c("STOREY")
	for level in _c("TOWER_VISITED_STOREYS"):
		var h: float = level * storey
		_begin(_kit.world(104, 100, h + 1.5))
		if level == 0:
			_hall(lights)
		else:
			_corridor(lights, level, h)
			_flats(lights, level, h)
		_stairwell(lights, level, h)
		_commit(node, "Storey%d" % level)
	_begin(_kit.world(116, 97, -1.5))
	_cellar_decor(lights)
	_commit(node, "Cellars")
	_begin(_kit.world(150, 72, 1.5))
	_great_hall(lights)
	_commit(node, "SocialCentreHall", WIDE_DECOR_DISTANCE)
	_begin(_kit.world(169, 72, 1.5))
	_offices()
	_commit(node, "SocialCentreOffices", WIDE_DECOR_DISTANCE)
	_begin(_kit.world(55, 143, 1.5))
	_shops_west(lights)
	_commit(node, "GalleryWest", WIDE_DECOR_DISTANCE)
	_begin(_kit.world(77, 143, 1.5))
	_shops_east()
	_commit(node, "GalleryEast", WIDE_DECOR_DISTANCE)
	_begin(_kit.world(160, 106, -1.5))
	_car_park_decor(lights)
	_commit(node, "CarPark", WIDE_DECOR_DISTANCE)


func _begin(origin: Vector3) -> void:
	_offset = origin
	_decor = SurfaceTool.new()
	_decor.begin(Mesh.PRIMITIVE_TRIANGLES)


func _commit(parent: Node3D, node_name: String, distance := DECOR_DISTANCE) -> void:
	var mesh := ArrayMesh.new()
	_decor.set_material(DECOR)
	_decor.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = _offset
	instance.visibility_range_end = distance
	instance.visibility_range_end_margin = 2.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.owner = parent.owner


## A box from plan (x0, y0, h0) to (x1, y1, h1), turned by yaw (radians) about
## its center, painted or glowing.
func _box(
	x0: float,
	y0: float,
	h0: float,
	x1: float,
	y1: float,
	h1: float,
	color: Color,
	glow := false,
	yaw := 0.0
) -> void:
	var center: Vector3 = _kit.world((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h0 + h1) / 2.0) - _offset
	var size := Vector3(absf(x1 - x0), absf(h1 - h0), absf(y1 - y0))
	var xform := Transform3D(Basis(Vector3.UP, yaw), center)
	var tool := _decor
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var corner := (
				n * size[axis] / 2.0
				- u * size[(axis + 1) % 3] / 2.0
				- v * size[(axis + 2) % 3] / 2.0
			)
			var du := u * size[(axis + 1) % 3]
			var dv := v * size[(axis + 2) % 3]
			var quad := [corner, corner + du, corner + du + dv, corner + dv]
			if u.cross(v).dot(n) > 0.0:
				quad.reverse()
			# Faces turned up are a little lighter, the others a little darker.
			var shade := 1.0 if axis == 1 and side > 0.0 else 0.85 + 0.1 * float(axis == 0)
			var c := (
				Color(color.r, color.g, color.b, 0.0)
				if glow
				else Color(color.r * shade, color.g * shade, color.b * shade)
			)
			tool.set_normal(xform.basis * n)
			for k: int in [0, 1, 2, 0, 2, 3]:
				tool.set_color(c)
				tool.add_vertex(xform * quad[k])


## A thin sheet lying on the floor at height h.
func _sheet(x: float, y: float, h: float, w: float, d: float, color: Color) -> void:
	_box(
		x - w / 2.0,
		y - d / 2.0,
		h + 0.002,
		x + w / 2.0,
		y + d / 2.0,
		h + 0.008,
		color,
		false,
		_rng.randf_range(0.0, PI)
	)


## Sheets of paper scattered in a plan rectangle.
func _papers(r: Rect2, h: float, count: int) -> void:
	for i in count:
		var tone := _rng.randf_range(0.8, 1.05)
		_sheet(
			_rng.randf_range(r.position.x, r.end.x),
			_rng.randf_range(r.position.y, r.end.y),
			h,
			0.21,
			0.3,
			PAPER * tone
		)


## A real light at a plan point, faded out with distance like the street
## lights; under Props it is baked into the walls too.
func _light(
	parent: Node3D, x: float, y: float, h: float, color: Color, energy: float, light_range: float
) -> void:
	var light := OmniLight3D.new()
	light.name = "Lamp%d" % parent.get_child_count()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_cull_mask = ~MapKit.BAKED_LAYER & 0xFFFFF
	light.distance_fade_enabled = true
	light.distance_fade_begin = _c("LIGHT_FADE_BEGIN")
	light.distance_fade_length = _c("LIGHT_FADE_LENGTH")
	light.position = _kit.world(x, y, h)
	parent.add_child(light)
	light.owner = parent.owner


## A caged round lamp under the ceiling at plan (x, y), its glass at height top.
func _hublot(x: float, y: float, top: float, alive: bool) -> void:
	_box(
		x - 0.15,
		y - 0.15,
		top - 0.06,
		x + 0.15,
		y + 0.15,
		top,
		LAMP_COLOR if alive else DEAD_GLASS,
		alive
	)
	for d: float in [-0.07, 0.0, 0.07]:
		_box(x + d - 0.008, y - 0.16, top - 0.075, x + d + 0.008, y + 0.16, top - 0.06, DARK)


## The same lamp on a wall facing +Y (toward the south), centred at x, z.
func _wall_hublot(x: float, wall_y: float, z: float, alive: bool) -> void:
	_box(
		x - 0.15,
		wall_y,
		z - 0.15,
		x + 0.15,
		wall_y + 0.06,
		z + 0.15,
		LAMP_COLOR if alive else DEAD_GLASS,
		alive
	)
	for d: float in [-0.07, 0.0, 0.07]:
		_box(x + d - 0.008, wall_y + 0.06, z - 0.16, x + d + 0.008, wall_y + 0.075, z + 0.16, DARK)


## A fluorescent tube along x under the ceiling.
func _tube(x: float, y: float, top: float, alive: bool) -> void:
	_box(x - 0.65, y - 0.07, top - 0.04, x + 0.65, y + 0.07, top, Color(0.3, 0.31, 0.3))
	_box(
		x - 0.6,
		y - 0.04,
		top - 0.07,
		x + 0.6,
		y + 0.04,
		top - 0.04,
		TUBE_COLOR if alive else DEAD_GLASS,
		alive
	)


## A painted seven-segment digit on a wall facing +Y, its bottom-left at x, z.
func _digit(value: int, x: float, wall_y: float, z: float, color: Color) -> void:
	var w := 0.32
	var hh := 0.3
	var t := 0.07
	var segments: Array = DIGITS.get(value, DIGITS[1])
	var rects := [
		[0, 2 * hh - t, w, 2 * hh],
		[w - t, hh, w, 2 * hh],
		[w - t, 0, w, hh],
		[0, 0, w, t],
		[0, 0, t, hh],
		[0, hh, t, 2 * hh],
		[0, hh - t / 2, w, hh + t / 2],
	]
	for i in 7:
		if segments[i]:
			var r: Array = rects[i]
			_box(x + r[0], wall_y, z + r[1], x + r[2], wall_y + 0.01, z + r[3], color)


func _hall(lights: Node3D) -> void:
	var ceiling: float = _c("STOREY") - _c("SLAB")
	_tube(104.0, 102.0, ceiling, true)
	_light(lights, 104.0, 102.0, ceiling - 0.3, TUBE_COLOR, 1.1, 6.0)
	# The tube over the letter boxes still works, barely.
	_tube(112.5, 94.5, ceiling, true)
	_light(lights, 112.5, 94.5, ceiling - 0.3, TUBE_COLOR, 0.6, 5.0)
	_tube(110.0, 106.0, ceiling, false)
	# Letter boxes on the west face of the block at x = 114.6, three rows.
	var face := 114.6
	var forced := [3, 8, 17, 30]
	var n := 0
	for row in 3:
		for col in 13:
			var y0 := 92.0 + col * 0.385
			var z0 := 0.82 + row * 0.32
			if forced.has(n):
				_box(face - 0.01, y0 + 0.01, z0, face, y0 + 0.37, z0 + 0.3, DARK)
				_box(
					face - 0.04,
					y0 + 0.02,
					z0 - 0.26,
					face - 0.02,
					y0 + 0.36,
					z0 + 0.02,
					STEEL * 0.8
				)
			else:
				_box(
					face - 0.02,
					y0 + 0.01,
					z0 + 0.01,
					face,
					y0 + 0.37,
					z0 + 0.3,
					STEEL * _rng.randf_range(0.8, 1.05)
				)
				_box(face - 0.025, y0 + 0.08, z0 + 0.22, face - 0.02, y0 + 0.3, z0 + 0.24, DARK)
				_box(face - 0.025, y0 + 0.05, z0 + 0.05, face - 0.02, y0 + 0.17, z0 + 0.1, PAPER)
			n += 1
	_papers(Rect2(113.0, 92.0, 1.4, 5.0), 0.03, 12)
	_papers(Rect2(101.0, 100.0, 12.0, 8.0), 0.03, 10)
	# A pram left by the south doors, bin bags in the bin room.
	_box(112.2, 110.4, 0.35, 113.1, 111.0, 0.75, Color(0.18, 0.2, 0.24))
	_box(112.2, 110.4, 0.75, 112.5, 111.0, 1.05, Color(0.18, 0.2, 0.24))
	for wx: float in [112.25, 112.95]:
		_box(wx, 110.35, 0.03, wx + 0.2, 110.4, 0.33, DARK)
		_box(wx, 111.0, 0.03, wx + 0.2, 111.05, 0.33, DARK)
	_bags(Vector2(93.2, 111.2), 0.03, 4)
	_bags(Vector2(97.6, 104.8), 0.03, 2)
	# The green exit sign above the south doors.
	_box(104.4, 111.6, 2.45, 105.6, 111.65, 2.62, EXIT_COLOR, true)


func _bags(at: Vector2, h: float, count: int) -> void:
	for i in count:
		var x := at.x + _rng.randf_range(-0.5, 0.5)
		var y := at.y + _rng.randf_range(-0.4, 0.4)
		var s := _rng.randf_range(0.2, 0.26)
		_box(x - s, y - s, h, x + s, y + s, h + s * 1.8, DARK, false, _rng.randf_range(0.0, PI))


func _corridor(lights: Node3D, level: int, h: float) -> void:
	var corridor: Vector2 = _c("CORRIDOR")
	var ceiling: float = h + _c("STOREY") - _c("SLAB")
	var mid := (corridor.x + corridor.y) / 2.0
	var alive := level % CORRIDOR_LAMPS.size()
	for i in CORRIDOR_LAMPS.size():
		_hublot(CORRIDOR_LAMPS[i], mid, ceiling, i == alive)
	_light(lights, CORRIDOR_LAMPS[alive], mid, ceiling - 0.3, LAMP_COLOR, 1.0, 5.0)
	var door_width: float = _c("DOOR_WIDTH")
	var wall: float = _c("WALL")
	for door: Array in FRONT_DOORS:
		var x: float = door[0] + door_width / 2.0
		var north: bool = door[1]
		var face := corridor.x + wall / 2.0 if north else corridor.y - wall / 2.0
		var step := 1.0 if north else -1.0
		# Doormat, and the brass number beside the door.
		_box(
			x - 0.4,
			face + step * 0.05,
			h,
			x + 0.4,
			face + step * 0.55,
			h + 0.015,
			MAT_BROWN * _rng.randf_range(0.8, 1.2)
		)
		var plate: float = door[0] + door_width + 0.2
		_box(plate, face, h + 1.6, plate + 0.14, face + step * 0.02, h + 1.68, BRASS)
	_papers(Rect2(93.0, corridor.x + 0.3, 21.0, corridor.y - corridor.x - 0.6), h, 9)
	if level % 2 == 1:
		_bags(Vector2(93.0, mid), h, 2)
	if level == 2:
		# A child's tricycle left against the wall.
		_box(
			95.0,
			corridor.y - 0.55,
			h + 0.28,
			95.3,
			corridor.y - 0.35,
			h + 0.33,
			Color(0.42, 0.38, 0.12)
		)
		_box(95.3, corridor.y - 0.48, h + 0.1, 95.5, corridor.y - 0.42, h + 0.5, STEEL)
		_box(95.5, corridor.y - 0.48, h, 95.52, corridor.y - 0.42, h + 0.3, DARK)
	# A child's drawing taped on the wall.
	var dx := 103.0 if level % 2 == 0 else 95.6
	var south := corridor.y - wall / 2.0
	_box(dx, south - 0.01, h + 1.25, dx + 0.3, south, h + 1.65, PAPER * 1.1)
	_box(
		dx + 0.06,
		south - 0.012,
		h + 1.35,
		dx + 0.24,
		south - 0.01,
		h + 1.42,
		Color(0.15, 0.25, 0.4)
	)
	_box(
		dx + 0.1, south - 0.012, h + 1.45, dx + 0.18, south - 0.01, h + 1.55, Color(0.4, 0.38, 0.1)
	)
	# The green exit sign above the door of the fire escape.
	var east: float = _c("TOWER").end.x - wall
	_box(east - 0.05, mid - 0.3, h + 2.45, east, mid + 0.3, h + 2.62, EXIT_COLOR, true)


func _stairwell(lights: Node3D, level: int, h: float) -> void:
	var landing: float = _c("STAIR_LANDING_Y")
	var north: float = landing - _c("STAIR_FLIGHT_LENGTH") - _c("STAIR_MID_LANDING")
	var stair_x: float = _c("STAIR_X")
	var mid_h: float = h + _c("STOREY") / 2.0
	var alive := level % 2 == 0
	_wall_hublot(stair_x + 2.2, north, mid_h + 1.9, alive)
	if alive:
		_light(lights, stair_x + 2.2, north + 0.6, mid_h + 1.7, LAMP_COLOR, 0.9, 4.5)
	if level + 1 < _c("TOWER_VISITED_STOREYS"):
		_digit(level + 1, stair_x + 0.5, north, mid_h + 0.9, Color(0.1, 0.17, 0.14))
	_papers(Rect2(stair_x + 0.2, north + 0.2, 4.0, 1.0), mid_h, 2)


func _flats(lights: Node3D, level: int, h: float) -> void:
	var wall: float = _c("WALL")
	var r: Rect2 = _c("TOWER")
	var corridor: Vector2 = _c("CORRIDOR")
	# TVs left on, on the tables of the east flats.
	for entry: Array in TV_TABLES:
		var at: Vector2 = entry[0]
		if not entry[1].has(level):
			continue
		var top := h + TABLE_TOP
		_box(
			at.x - 0.25,
			at.y - 0.3,
			top,
			at.x + 0.25,
			at.y + 0.1,
			top + 0.4,
			Color(0.12, 0.13, 0.15)
		)
		_box(
			at.x - 0.2, at.y + 0.1, top + 0.06, at.x + 0.2, at.y + 0.11, top + 0.36, TV_COLOR, true
		)
		_light(lights, at.x, at.y + 0.8, top + 0.3, TV_COLOR, 0.8, 4.0)
	# Family photos between two windows of each living room.
	var y_north := r.position.y + wall
	_frames(106.4, y_north, h, 1.0)
	_frames(97.4, y_north, h, 1.0)
	_frames(94.0, 107.0 - wall / 2.0, h, -1.0)
	_frames(112.0, 107.0 - wall / 2.0, h, -1.0)
	# Calendar and clock in the kitchens, on their west wall, between windows.
	for face: float in [r.position.x + wall, 110.0 + wall / 2.0]:
		_box(face, 108.3, h + 1.3, face + 0.01, 108.65, h + 1.75, PAPER)
		_box(face, 109.2, h + 1.9, face + 0.03, 109.5, h + 2.2, Color(0.5, 0.5, 0.46))
	# Floors: papers everywhere, a toy, a fallen frame, bottles.
	var rooms := [
		Rect2(92.6, 88.6, 8.0, 9.5),
		Rect2(105.8, 88.6, 9.6, 9.5),
		Rect2(92.6, corridor.y + 0.4, 11.0, 5.0),
		Rect2(104.4, corridor.y + 0.4, 11.0, 5.0),
	]
	for room: Rect2 in rooms:
		_papers(room, h, 6)
		var p := room.position + Vector2(_rng.randf() * room.size.x, _rng.randf() * room.size.y)
		_box(
			p.x - 0.12,
			p.y - 0.08,
			h,
			p.x + 0.12,
			p.y + 0.08,
			h + 0.12,
			Color(0.42, 0.38, 0.14),
			false,
			_rng.randf() * PI
		)
		p = room.position + Vector2(_rng.randf() * room.size.x, _rng.randf() * room.size.y)
		_box(
			p.x - 0.035,
			p.y - 0.15,
			h,
			p.x + 0.035,
			p.y + 0.15,
			h + 0.07,
			Color(0.06, 0.12, 0.08),
			false,
			_rng.randf() * PI
		)
		p = room.position + Vector2(_rng.randf() * room.size.x, _rng.randf() * room.size.y)
		_box(
			p.x - 0.15,
			p.y - 0.2,
			h,
			p.x + 0.15,
			p.y + 0.2,
			h + 0.03,
			WOOD,
			false,
			_rng.randf() * PI
		)


## Three framed photos on a wall at y (facing +Y if out > 0, else -Y).
func _frames(x: float, wall_y: float, h: float, out: float) -> void:
	var spots := [[0.0, 1.5], [0.4, 1.62], [0.2, 1.98]]
	for spot: Array in spots:
		if _rng.randf() < 0.25:
			continue  # Taken, or fallen.
		var fx: float = x + spot[0]
		var fz: float = h + spot[1]
		_box(fx, wall_y, fz, fx + 0.3, wall_y + out * 0.025, fz + 0.38, WOOD)
		var tone := Color(
			_rng.randf_range(0.25, 0.45), _rng.randf_range(0.25, 0.4), _rng.randf_range(0.22, 0.35)
		)
		_box(
			fx + 0.04,
			wall_y + out * 0.025,
			fz + 0.04,
			fx + 0.26,
			wall_y + out * 0.03,
			fz + 0.34,
			tone
		)


func _cellar_decor(lights: Node3D) -> void:
	var corridor: Rect2 = _c("CELLAR_CORRIDOR")
	var ceiling: float = -_c("GROUND_THICKNESS")
	var y := corridor.get_center().y
	for x: float in CELLAR_BULBS:
		var alive := CELLAR_BULBS_ALIVE.has(x)
		_box(x - 0.008, y - 0.008, ceiling - 0.35, x + 0.008, y + 0.008, ceiling, DARK)
		_box(
			x - 0.05,
			y - 0.05,
			ceiling - 0.45,
			x + 0.05,
			y + 0.05,
			ceiling - 0.35,
			BULB_COLOR if alive else DEAD_GLASS,
			alive
		)
		if alive:
			_light(lights, x, y, ceiling - 0.6, BULB_COLOR, 0.9, 5.0)
	# A pipe along the ceiling, papers and bags on the floor.
	_box(
		corridor.position.x + 6.0,
		corridor.end.y - 0.25,
		ceiling - 0.25,
		corridor.end.x,
		corridor.end.y - 0.1,
		ceiling - 0.1,
		Color(0.3, 0.27, 0.22)
	)
	var floor_h: float = -_c("CAR_PARK_DEPTH")
	_papers(
		Rect2(
			corridor.position.x + 6.0,
			corridor.position.y + 0.3,
			corridor.size.x - 6.0,
			corridor.size.y - 0.6
		),
		floor_h,
		10
	)
	_bags(Vector2(110.0, corridor.end.y - 0.5), floor_h, 3)


## The great hall of the social centre and its kitchen: the last party, never
## cleared away.
func _great_hall(lights: Node3D) -> void:
	var r: Rect2 = _c("SOCIAL_CENTRE")
	var wall: float = _c("WALL")
	var ceiling: float = _c("SOCIAL_CENTRE_HEIGHT")
	# Two rows of tubes, one still alive over the tables.
	for x: float in [146.0, 152.0, 158.0]:
		for y: float in [66.0, 77.0]:
			var alive := x == 152.0 and y == 66.0
			_tube(x, y, ceiling, alive)
	_light(lights, 152.0, 66.0, ceiling - 0.4, TUBE_COLOR, 1.1, 6.0)
	# Bunting across the hall, from wall to wall, sagging in the middle.
	for line: float in [66.0, 74.0]:
		var x0 := r.position.x + wall
		var n := 26
		var step := (160.0 - x0) / n
		for i in n:
			var t := (i + 0.5) / n
			var z := ceiling - 0.6 - 0.8 * 4.0 * t * (1.0 - t)
			var x := x0 + i * step
			if _rng.randf() < 0.15:
				continue  # Torn off.
			_box(
				x + 0.1,
				line - 0.005,
				z - 0.3,
				x + step - 0.1,
				line + 0.005,
				z,
				BUNTING[i % BUNTING.size()]
			)
	# A banner over the stage, half fallen.
	var stage: Rect2 = _c("CENTRE_STAGE")
	_box(stage.end.x + 0.05, 66.0, 2.6, stage.end.x + 0.07, 73.0, 3.1, PAPER * 0.9, false, 0.0)
	_box(stage.end.x + 0.07, 67.0, 2.75, stage.end.x + 0.08, 71.5, 2.95, Color(0.12, 0.2, 0.42))
	# Paper plates and cups on the tables, more on the floor.
	for t: Vector2 in [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]:
		for i in 5:
			var p := t + Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.4, 0.4))
			if _rng.randf() < 0.5:
				_box(p.x - 0.11, p.y - 0.11, 0.75, p.x + 0.11, p.y + 0.11, 0.76, PAPER * 1.1)
			else:
				_box(
					p.x - 0.04,
					p.y - 0.04,
					0.75,
					p.x + 0.04,
					p.y + 0.04,
					0.86,
					Color(0.5, 0.5, 0.52)
				)
	_papers(_rect(145.0, 62.0, 159.0, 82.0), 0.0, 22)
	_bags(Vector2(158.5, 63.0), 0.0, 3)
	# Children's drawings taped along the north wall, the exit signs.
	var north := r.position.y + wall
	for i in 7:
		var x := 145.0 + i * 1.7 + _rng.randf_range(-0.2, 0.2)
		if _rng.randf() < 0.3:
			continue
		var z := 1.3 + _rng.randf_range(-0.1, 0.15)
		_box(x, north, z, x + 0.42, north + 0.01, z + 0.3, PAPER * 1.1, false)
		var tone: Color = BUNTING[_rng.randi() % BUNTING.size()]
		_box(x + 0.08, north + 0.01, z + 0.06, x + 0.3, north + 0.015, z + 0.2, tone)
	var west: Vector2 = _c("CENTRE_WEST_DOORS")
	var sign_y := (west.x + west.y) / 2.0
	_box(
		r.position.x + wall,
		sign_y - 0.6,
		2.5,
		r.position.x + wall + 0.05,
		sign_y + 0.6,
		2.67,
		EXIT_COLOR,
		true
	)
	# The kitchen: a dead tube, pans on the floor, the calendar of that year.
	var kitchen: Rect2 = _c("CENTRE_KITCHEN")
	_tube(156.0, 81.0, ceiling, false)
	_box(
		kitchen.position.x + wall / 2.0,
		82.5,
		1.3,
		kitchen.position.x + wall / 2.0 + 0.01,
		82.85,
		1.75,
		PAPER
	)
	for i in 3:
		var p := Vector2(_rng.randf_range(153.0, 158.5), _rng.randf_range(79.5, 83.0))
		_box(
			p.x - 0.14,
			p.y - 0.14,
			0.0,
			p.x + 0.14,
			p.y + 0.14,
			0.12,
			STEEL * 0.8,
			false,
			_rng.randf() * PI
		)


## The corridor and the offices of the social centre: notices, files, desks.
func _offices() -> void:
	var r: Rect2 = _c("SOCIAL_CENTRE")
	var ceiling: float = _c("SOCIAL_CENTRE_HEIGHT")
	# Corridor: dead hublots, a notice board, the exit sign.
	for y: float in [64.0, 72.0, 80.0]:
		_hublot(161.5, y, ceiling, false)
	var board := 160.0 + 0.15
	_box(board, 76.5, 1.2, board + 0.03, 78.5, 2.1, Color(0.3, 0.22, 0.14))
	for i in 9:
		var y := 76.6 + _rng.randf() * 1.6
		var z := 1.3 + _rng.randf() * 0.6
		_box(
			board + 0.03,
			y,
			z,
			board + 0.04,
			y + 0.21,
			z + 0.27,
			PAPER * _rng.randf_range(0.85, 1.1),
			false
		)
	_box(160.9, r.end.y - 0.35, 2.5, 162.1, r.end.y - 0.3, 2.67, EXIT_COLOR, true)
	_papers(_rect(160.3, 61.0, 162.7, 83.0), 0.0, 8)
	# Offices: a dead tube each, files on the desks and the floor, a screen.
	for y: float in [64.0, 72.0, 80.0]:
		_tube(170.5, y, ceiling, false)
		var desk := Vector2(172.0, y)
		_box(
			desk.x - 0.25,
			desk.y - 0.2,
			0.75,
			desk.x + 0.15,
			desk.y + 0.2,
			1.08,
			Color(0.5, 0.48, 0.42)
		)
		_box(desk.x - 0.26, desk.y - 0.16, 0.8, desk.x - 0.25, desk.y + 0.16, 1.04, DARK)
		for i in 3:
			var p := desk + Vector2(_rng.randf_range(0.2, 0.7), _rng.randf_range(-0.3, 0.3))
			_box(
				p.x - 0.12,
				p.y - 0.16,
				0.75,
				p.x + 0.12,
				p.y + 0.16,
				0.75 + 0.02 * (i + 1),
				PAPER,
				false,
				_rng.randf() * 0.5
			)
		_papers(_rect(164.0, y - 3.5, 177.0, y + 3.5), 0.0, 9)
		# A filing cabinet against the east wall, a drawer left open.
		var east: float = r.end.x - _c("WALL")
		_box(east - 0.5, y + 1.5, 0.0, east, y + 2.0, 1.3, Color(0.32, 0.34, 0.32))
		_box(east - 0.85, y + 1.55, 0.75, east - 0.5, y + 1.95, 0.95, Color(0.3, 0.32, 0.3))
	# A wall clock stopped in the middle office.
	_box(r.end.x - 0.31, 70.4, 2.2, r.end.x - 0.28, 70.8, 2.6, Color(0.5, 0.5, 0.46))


## The pharmacy, the laundrette and the tobacconist.
func _shops_west(lights: Node3D) -> void:
	var r: Rect2 = _c("GALLERY")
	var h: float = _c("GALLERY_HEIGHT")
	var front: float = r.position.y + _c("GALLERY_ARCADE_DEPTH") + _c("WALL") / 2.0
	var back: float = r.end.y - _c("GALLERY_BACK_CORRIDOR")
	var width: float = r.size.x / SHOP_TILES.size()
	# The pharmacy's green cross, still lit over its door, inside the window.
	var cx := 49.5
	_box(cx - 0.35, front + 0.05, 2.75, cx + 0.35, front + 0.1, 2.95, EXIT_COLOR, true)
	_box(cx - 0.1, front + 0.05, 2.5, cx + 0.1, front + 0.1, 3.2, EXIT_COLOR, true)
	# Boxes of medicine thrown down, papers.
	for i in 14:
		var p := Vector2(_rng.randf_range(45.6, 53.0), _rng.randf_range(front + 0.6, back - 0.5))
		_box(
			p.x - 0.08,
			p.y - 0.05,
			0.0,
			p.x + 0.08,
			p.y + 0.05,
			0.06,
			PAPER * _rng.randf_range(0.9, 1.15),
			false,
			_rng.randf() * PI
		)
	_papers(_rect(45.6, front + 0.4, 53.0, back - 0.3), 0.0, 6)
	# Laundrette: the one tube that still works, portholes on the machines,
	# a basket of forgotten washing.
	var laundrette := r.position.x + width
	_tube(laundrette + 4.2, 143.0, h, true)
	_light(lights, laundrette + 4.2, 143.0, h - 0.4, TUBE_COLOR, 1.0, 5.5)
	_tube(laundrette + 4.2, 140.5, h, false)
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		var face := back - 1.0
		_box(mx - 0.25, face - 0.01, 0.3, mx + 0.25, face, 0.75, Color(0.1, 0.12, 0.13))
		_box(mx - 0.18, face - 0.02, 0.37, mx + 0.18, face - 0.01, 0.68, Color(0.2, 0.26, 0.28))
	_box(laundrette + 3.0, 143.0, 0.0, laundrette + 3.6, 143.4, 0.3, Color(0.35, 0.36, 0.3))
	_box(laundrette + 3.05, 143.05, 0.3, laundrette + 3.55, 143.35, 0.38, Color(0.2, 0.25, 0.32))
	_papers(_rect(laundrette + 0.5, front + 0.5, laundrette + width - 0.5, back - 1.3), 0.0, 5)
	# Tobacconist: lottery slips everywhere, a poster.
	var tabac := r.position.x + 2.0 * width
	for i in 30:
		var p := Vector2(
			_rng.randf_range(tabac + 0.5, tabac + width - 0.5),
			_rng.randf_range(front + 0.5, back - 0.5)
		)
		_box(
			p.x - 0.04,
			p.y - 0.08,
			0.0,
			p.x + 0.04,
			p.y + 0.08,
			0.004,
			Color(0.5, 0.48, 0.3),
			false,
			_rng.randf() * PI
		)
	_box(tabac + width - 0.2, 141.0, 1.2, tabac + width - 0.15, 142.0, 2.0, Color(0.12, 0.2, 0.42))


## The grocer, the baker and the delivery corridor.
func _shops_east() -> void:
	var r: Rect2 = _c("GALLERY")
	var front: float = r.position.y + _c("GALLERY_ARCADE_DEPTH") + _c("WALL") / 2.0
	var back: float = r.end.y - _c("GALLERY_BACK_CORRIDOR")
	var width: float = r.size.x / SHOP_TILES.size()
	var h: float = _c("GALLERY_HEIGHT")
	# Grocer: crates, tins rolled under the counter, a dead tube.
	var grocer := r.position.x + 3.0 * width
	_tube(grocer + 4.2, 143.0, h, false)
	for i in 4:
		var x := grocer + 0.6 + i * 0.7
		_box(
			x,
			back - 0.7,
			0.0,
			x + 0.6,
			back - 0.3,
			0.3,
			WOOD * 1.3,
			false,
			_rng.randf_range(-0.1, 0.1)
		)
	for i in 9:
		var p := Vector2(
			_rng.randf_range(grocer + 0.5, grocer + width - 0.5),
			_rng.randf_range(front + 0.5, back - 1.0)
		)
		_box(
			p.x - 0.04,
			p.y - 0.06,
			0.0,
			p.x + 0.04,
			p.y + 0.06,
			0.08,
			STEEL,
			false,
			_rng.randf() * PI
		)
	# Baker: the price board, paper bags, flour on the floor.
	var baker := r.position.x + 4.0 * width
	_tube(baker + 4.2, 143.0, h, false)
	_box(baker + 1.0, back - 0.2, 1.6, baker + 2.6, back - 0.15, 2.3, DARK)
	for i in 6:
		_box(
			baker + 1.1,
			back - 0.21,
			2.15 - i * 0.1,
			baker + 1.1 + _rng.randf_range(0.6, 1.3),
			back - 0.2,
			2.17 - i * 0.1,
			PAPER * 1.1
		)
	for i in 6:
		var p := Vector2(
			_rng.randf_range(baker + 0.5, baker + width - 0.5),
			_rng.randf_range(front + 0.5, back - 0.5)
		)
		_box(
			p.x - 0.1,
			p.y - 0.06,
			0.0,
			p.x + 0.1,
			p.y + 0.06,
			0.03,
			Color(0.55, 0.5, 0.4),
			false,
			_rng.randf() * PI
		)
	_box(
		baker + 4.0,
		front + 2.0,
		0.0,
		baker + 5.2,
		front + 2.8,
		0.004,
		Color(0.6, 0.6, 0.57),
		false,
		0.4
	)
	# Delivery corridor: bulbs, all dead, bags and crates.
	var corridor_y := (back + r.end.y) / 2.0
	for x: float in [50.0, 60.0, 70.0, 80.0]:
		_box(
			x - 0.05, corridor_y - 0.05, h - 0.45, x + 0.05, corridor_y + 0.05, h - 0.35, DEAD_GLASS
		)
		_box(x - 0.008, corridor_y - 0.008, h - 0.35, x + 0.008, corridor_y + 0.008, h, DARK)
	_bags(Vector2(76.0, corridor_y), 0.0, 3)
	_bags(Vector2(53.0, corridor_y), 0.0, 2)
	_papers(_rect(r.position.x + 1.0, back + 0.3, r.end.x - 1.0, r.end.y - 0.3), 0.0, 10)


## The car park: tubes, mostly dead, painted bays, tyres, a trolley.
func _car_park_decor(lights: Node3D) -> void:
	var r: Rect2 = _c("CAR_PARK")
	var floor_h: float = -_c("CAR_PARK_DEPTH")
	var ceiling: float = -_c("GROUND_THICKNESS")
	for at: Vector2 in CAR_PARK_TUBES:
		var alive := CAR_PARK_TUBES_ALIVE.has(at)
		_tube(at.x, at.y, ceiling, alive)
		if alive:
			_light(lights, at.x, at.y, ceiling - 0.4, TUBE_COLOR, 1.2, 6.0)
	# Bays along the north and south walls, their lines worn.
	for x in range(int(r.position.x) + 3, 169, 3):
		for y: Array in [[r.position.y + 0.4, r.position.y + 5.0], [r.end.y - 5.0, r.end.y - 0.4]]:
			if _rng.randf() < 0.2:
				continue
			_box(
				x - 0.05,
				y[0],
				floor_h + 0.002,
				x + 0.05,
				y[1],
				floor_h + 0.006,
				Color(0.5, 0.5, 0.47) * _rng.randf_range(0.6, 1.0)
			)
	# Pillar numbers, the exit signs over the stairs.
	var px: float = r.position.x + _c("CAR_PARK_PILLAR_STEP")
	var n := 1
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			_box(
				px - 0.26,
				py - 0.26,
				floor_h + 1.4,
				px + 0.26,
				py + 0.26,
				floor_h + 1.7,
				Color(0.35, 0.36, 0.2)
			)
			_digit(n % 10, px - 0.16, py - 0.27, floor_h + 1.8, Color(0.08, 0.08, 0.08))
			n += 1
		px += _c("CAR_PARK_PILLAR_STEP")
	var north: Rect2 = _c("CAR_PARK_NORTH_STAIRS")
	_box(
		north.end.x + 0.32,
		north.get_center().y - 0.3,
		floor_h + 2.5,
		north.end.x + 0.37,
		north.get_center().y + 0.3,
		floor_h + 2.67,
		EXIT_COLOR,
		true
	)
	var stairs: Rect2 = _c("CAR_PARK_STAIRS")
	_box(
		stairs.position.x - 0.6,
		stairs.position.y - 0.37,
		floor_h + 2.5,
		stairs.position.x + 0.6,
		stairs.position.y - 0.32,
		floor_h + 2.67,
		EXIT_COLOR,
		true
	)
	# Tyres stacked, a shopping trolley on its side, puddles, rubbish.
	for i in 3:
		_box(
			147.0,
			115.3,
			floor_h + i * 0.22,
			147.65,
			115.95,
			floor_h + 0.2 + i * 0.22,
			DARK,
			false,
			i * 0.3
		)
	_box(163.0, 105.0, floor_h, 163.9, 105.6, floor_h + 0.55, STEEL * 0.7, false, 0.6)
	for i in 5:
		var p := Vector2(
			_rng.randf_range(r.position.x + 2.0, r.end.x - 8.0),
			_rng.randf_range(r.position.y + 6.0, r.end.y - 6.0)
		)
		_box(
			p.x - 1.0,
			p.y - 0.6,
			floor_h + 0.001,
			p.x + 1.0,
			p.y + 0.6,
			floor_h + 0.003,
			Color(0.05, 0.06, 0.07),
			false,
			_rng.randf() * PI
		)
	_papers(
		_rect(r.position.x + 1.0, r.position.y + 1.0, r.end.x - 7.0, r.end.y - 1.0), floor_h, 16
	)
	_bags(Vector2(171.0, 110.0), floor_h, 4)


static func _rect(ax: float, ay: float, bx: float, by: float) -> Rect2:
	return Rect2(ax, ay, bx - ax, by - ay)
