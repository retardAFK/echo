extends RefCounted
## Shared constants, state and drawing helpers of the interior lining
## (S-019, S-022 T-432): boxes, papers, lamps, hublots, tubes, digits.
## Chain: interior_lining_kit.gd → interior_lining_rooms.gd →
## interior_lining.gd (the one the generator and the tests use).

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
	WARD_CORRIDOR,
	FAIENCE,
	WARD,
	WARD_LINO,
}

const MapKit := preload("res://tools/godot/map_kit.gd")

const Hospital := preload("res://tools/godot/hospital.gd")

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

## The hospital's corridors: decor meshes per level, tube spacing, the share
## of tubes still alive.
const HOSPITAL_STRETCHES := 3

const HOSPITAL_TUBE_STEP := 6.0

const HOSPITAL_ALIVE := 0.3

## Far enough to see the next stretch's tubes down the corridor, into the fog.
const HOSPITAL_DECOR_DISTANCE := 32.0

## The car park's puddles, world boxes at floor level (S-012, T-143).
var puddles: Array[AABB] = []

var _constants: Dictionary

var _kit: RefCounted

var _rng := RandomNumberGenerator.new()

var _decor: SurfaceTool

## Origin of the decor mesh being built: its node stands there, so the
## distance it is drawn from is measured from the middle of its storey.
var _offset := Vector3.ZERO


func _init(builder: Object) -> void:
	# The generator is split in a chain of scripts (S-022, T-432): read the
	# constants of every script in the chain, the nearest one first.
	var script: Script = builder.get_script()
	while script != null:
		var constants := script.get_script_constant_map()
		for key: String in constants:
			if not _constants.has(key):
				_constants[key] = constants[key]
		script = script.get_base_script()


func _c(key: String) -> Variant:
	return _constants[key]


## Whether a stuttering NeonTube hangs there (its case is drawn here, dark).
func _is_neon(x: float, h: float, y: float) -> bool:
	for neon: Vector3 in Hospital.NEONS:
		if is_equal_approx(neon.y, h) and Vector2(neon.x - x, neon.z - y).length() < 1.0:
			_tube_y(x, y, _kit_ceiling(h), false)
			return true
	return false


func _kit_ceiling(h: float) -> float:
	return h + Hospital.STOREY - _c("SLAB")


# --- Decor and lamps ------------------------------------------------------------


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


## The same tube along y (plan north-south).
func _tube_y(x: float, y: float, top: float, alive: bool) -> void:
	_box(x - 0.07, y - 0.65, top - 0.04, x + 0.07, y + 0.65, top, Color(0.3, 0.31, 0.3))
	if alive:
		_box(x - 0.04, y - 0.6, top - 0.07, x + 0.04, y + 0.6, top - 0.04, TUBE_COLOR, true)
	elif not is_nan(top):
		_box(x - 0.04, y - 0.6, top - 0.07, x + 0.04, y + 0.6, top - 0.04, DEAD_GLASS)


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


func _bags(at: Vector2, h: float, count: int) -> void:
	for i in count:
		var x := at.x + _rng.randf_range(-0.5, 0.5)
		var y := at.y + _rng.randf_range(-0.4, 0.4)
		var s := _rng.randf_range(0.2, 0.26)
		_box(x - s, y - s, h, x + s, y + s, h + s * 1.8, DARK, false, _rng.randf_range(0.0, PI))


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


static func _rect(ax: float, ay: float, bx: float, by: float) -> Rect2:
	return Rect2(ax, ay, bx - ax, by - ay)
