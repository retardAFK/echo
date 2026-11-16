extends RefCounted
## The Saint-Roch hospital of the cité des Tilleuls (spec S-014, T-183), in
## place of block C, from its paper plan (specs/S-014-hopital/plan-hopital.svg,
## tools/plans/make_hospital_plan.py): 22 x 76 m, four visited levels (the
## basement at -3 m, the ground floor, the 1st and 2nd floors), three more
## seen from outside only. A 74 m corridor runs north-south through each
## level, rooms on both sides, two switchback stairs (north-east, south-west),
## a metal fire escape on the south front from the 2nd floor, the morgue's
## quay down from the service alley, the emergency canopy to the east.
## Plan coordinates as everywhere in the generator: x east, y south, meters.

const MapKit := preload("res://tools/godot/map_kit.gd")

const RECT := Rect2(10, 56, 22, 76)
## The levels: their floor height, the basement first.
const LEVELS := [-3.0, 0.0, 3.0, 6.0]
const STOREY := 3.0
## Seen from outside: three storeys more, closed.
const STOREYS := 7
## The middle of the corridor's walls.
const CORRIDOR := Vector2(19.5, 22.5)
## The stairs: plan rectangle of the hole in each slab (flights and mid
## landing), the side of the corridor they leave from (1: east, -1: west).
const NORTH_STAIRS := Rect2(22.5, 56.3, 5.5, 4.4)
const SOUTH_STAIRS := Rect2(14.0, 127.3, 5.5, 4.4)
const FLIGHT_WIDTH := 2.0
const FLIGHT_LENGTH := 4.0
const DIVIDER := 0.4
## The lift shaft beside the hall, from the basement to the top; its cabin is
## stuck on the 2nd floor (a hiding spot, T-188).
const LIFT := Rect2(22.65, 88.2, 2.4, 2.4)
## The morgue's quay (basement, west): a ramp in the service alley from the
## ground at its north end down to an apron at the quay doors.
const ALLEY_X := 6.2
const QUAY_RAMP := Rect2(6.2, 78, 3.65, 10)
const QUAY_APRON := Rect2(6.2, 88, 3.65, 8)
const QUAY_DOORS := Vector2(89.0, 93.0)
## The emergency canopy, east, over the ambulance.
const CANOPY := Rect2(32, 88, 6, 24)
const CANOPY_HEIGHT := 3.2
## The fire escape (2nd floor to the ground), south of the corridor's end.
const ESCAPE_LANDING := Rect2(19.5, 132.15, 3.0, 2.2)
const ESCAPE_TOP := Rect2(22.5, 132.3, 8.0, 2.0)
const ESCAPE_BOTTOM := Rect2(22.5, 134.5, 8.0, 2.0)
const ESCAPE_MID := Rect2(30.5, 132.3, 2.0, 4.2)

## Rooms of each level, west then east of the corridor: [from y, to y, door
## y (the middle of a 1.2 m door) or an opening [from y, to y], or null for
## no door on the corridor]. Walls between two rooms stand at their bounds.
## Doors between rooms: LINKS. The stairs, lift and corridor are not rooms.
const WEST_ROOMS := {
	-3.0:
	[[56.0, 74.0, 65.0], [74.0, 86.0, 80.0], [86.0, 96.0, [89.8, 92.2]], [96.0, 127.0, 110.0]],
	0.0:
	[
		[56.0, 68.0, 62.0],
		[68.0, 80.0, 74.0],
		[80.0, 92.0, 88.0],
		[92.0, 104.0, [95.0, 101.0]],
		[104.0, 127.0, [108.0, 114.0]]
	],
	3.0:
	[
		[56.0, 68.0, 62.0],
		[68.0, 80.0, 74.0],
		[80.0, 92.0, 86.0],
		[92.0, 104.0, 98.0],
		[104.0, 114.5, 109.0],
		[114.5, 127.0, 120.0]
	],
	6.0:
	[
		[56.0, 70.0, 63.0],
		[70.0, 85.0, [76.4, 78.8]],
		[85.0, 100.0, [91.4, 93.8]],
		[100.0, 127.0, [104.0, 110.0]]
	],
}
const EAST_ROOMS := {
	-3.0:
	[
		[61.0, 67.5, 64.0],
		[67.5, 74.0, 70.5],
		[74.0, 80.5, 77.0],
		[80.5, 87.0, 83.5],
		[87.0, 100.0, 94.0],
		[100.0, 124.0, 112.0],
		[124.0, 132.0, 128.0]
	],
	0.0:
	[
		[61.0, 75.0, 68.0],
		[75.0, 88.0, [79.0, 84.0]],
		[91.0, 100.0, [92.0, 99.0]],
		[100.0, 112.0, [102.0, 110.0]],
		[112.0, 124.0, 118.0],
		[124.0, 132.0, 128.0]
	],
	3.0:
	[
		[61.0, 75.5, 68.0],
		[75.5, 88.0, 82.0],
		[91.0, 96.0, [91.5, 95.5]],
		[96.0, 110.0, 103.0],
		[110.0, 124.0, 117.0],
		[124.0, 132.0, 128.0]
	],
	6.0:
	[
		[61.0, 75.0, 68.0],
		[75.0, 88.0, 82.0],
		[91.0, 96.0, 93.5],
		[96.0, 124.0, [100.0, 120.0]],
		[124.0, 132.0, 128.0]
	],
}
## Doors in the walls between two rooms: level, side (-1 west, 1 east), the
## wall's y, the middle of the door along x.
const LINKS := [
	[-3.0, -1, 74.0, 15.0],  # Morgue and autopsy.
	[-3.0, 1, 100.0, 27.0],
	[-3.0, 1, 124.0, 27.0],  # Archives, linen room, technical room.
	[0.0, 1, 112.0, 27.0],  # Care room and emergency airlock.
	[6.0, -1, 70.0, 15.0],
	[6.0, -1, 85.0, 15.0],  # The operating theatres.
]
## Fire doors across the corridor (S-016, Q3): level, y.
const FIRE_DOORS := [
	[-3.0, 87.0], [-3.0, 100.0], [3.0, 80.0], [3.0, 108.0], [6.0, 75.0], [6.0, 100.0]
]
## Doors out (ground floor): the main entrance and the emergency entrance on
## the east front (double), the ends of the corridor (double), the pharmacy's
## emergency exit on the west front (y of the middle).
const MAIN_DOORS := Vector2(92.8, 95.2)
const EMERGENCY_DOORS := Vector2(104.8, 107.2)
const PHARMACY_EXIT := 85.6

## Lights that flicker under a scan: plan point (x, height, y), range.
const LIGHTS := [
	[Vector3(21, 2.6, 94), 8.0],
	[Vector3(21, 5.6, 90), 8.0],
	[Vector3(15, -0.6, 65), 7.0],
]

var kit: MapKit
var _builder: Object
var _wall: float
var _slab: float
var _door_top: float


func _init(builder: Object) -> void:
	_builder = builder
	kit = builder.kit
	_wall = builder.WALL
	_slab = builder.SLAB
	_door_top = builder.DOOR_TOP


## Holes in the ground slab of the cité: the stairs down, the quay's pit.
static func ground_holes() -> Array[Rect2]:
	return [NORTH_STAIRS, SOUTH_STAIRS, QUAY_RAMP.merge(QUAY_APRON)]


## The volume of the building for the scan, and its extra boxes (the quay's
## pit), as build_tilleuls.gd's _buildings() and _extra_boxes() want them.
static func scan_box() -> Array:
	return [RECT, LEVELS[0], LEVELS[-1] + STOREY]


static func extra_boxes() -> Array:
	return [[QUAY_RAMP.merge(QUAY_APRON), LEVELS[0], 0.0]]


func build() -> void:
	var s := kit.structure("Hospital")
	var concrete: Material = _builder.MAT_CONCRETE
	var obstacle: Material = _builder.MAT_OBSTACLE
	var r := RECT
	var top: float = LEVELS[-1] + STOREY
	# Upper mass, seen from the whole west of the cité.
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, top, STOREYS * STOREY, concrete)
	for h: float in LEVELS:
		_outer_walls(s, h)
		_floor(s, h, obstacle)
		_rooms(s, h, -1, WEST_ROOMS[h])
		_rooms(s, h, 1, EAST_ROOMS[h])
		if h < LEVELS[-1]:
			_stairs(s, NORTH_STAIRS, 1, h, obstacle)
			_stairs(s, SOUTH_STAIRS, -1, h, obstacle)
		for fire: Array in FIRE_DOORS:
			if is_equal_approx(fire[0], h):
				_fire_doors(s, h, fire[1])
	for link: Array in LINKS:
		_builder._door(Vector3(link[3], link[0], link[2]), 0.0, 1.2)
	_stairwells(s, concrete)
	kit.box(s, LIFT.position.x, LIFT.position.y, LIFT.end.x, LIFT.end.y, LEVELS[0], top, concrete)
	_quay(s, concrete)
	_canopy(s, concrete)
	_fire_escape(s)


## Outer walls of a level: windows above the basement, the doors out on the
## ground floor, the quay doors in the basement.
func _outer_walls(s: MapKit.Structure, h: float) -> void:
	var r := RECT
	var concrete: Material = _builder.MAT_CONCRETE
	var basement := h < 0.0
	var ceiling: float = -_builder.GROUND_THICKNESS if basement else h + STOREY
	var windows := func(from: float, to: float) -> Array:
		return [] if basement else _builder._windows(from, to, h)
	var corridor_gap := [[CORRIDOR.x + _wall / 2, CORRIDOR.y - _wall / 2, h + _door_top]]
	var north: Array = (
		windows.call(r.position.x, CORRIDOR.x - 0.5) + windows.call(CORRIDOR.y + 0.5, r.end.x)
	)
	var south := north.duplicate()
	if is_zero_approx(h):
		north.append_array(corridor_gap)
		south.append_array(corridor_gap)
	elif is_equal_approx(h, LEVELS[-1]):
		south.append_array(corridor_gap)
	kit.wall_x(
		s, r.position.x, r.end.x, r.position.y + _wall / 2, h, ceiling, _wall, concrete, north
	)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - _wall / 2, h, ceiling, _wall, concrete, south)
	var east: Array = windows.call(r.position.y, r.end.y)
	var west: Array = windows.call(r.position.y, r.end.y)
	if is_zero_approx(h):
		east = _clear(east, [MAIN_DOORS, EMERGENCY_DOORS])
		east.append([MAIN_DOORS.x, MAIN_DOORS.y, _door_top])
		east.append([EMERGENCY_DOORS.x, EMERGENCY_DOORS.y, _door_top])
		var exit := Vector2(PHARMACY_EXIT - 0.6, PHARMACY_EXIT + 0.6)
		west = _clear(west, [exit])
		west.append([exit.x, exit.y, _door_top])
	if basement:
		west.append([QUAY_DOORS.x, QUAY_DOORS.y, h + _door_top])
	kit.wall_y(
		s, r.position.y, r.end.y, r.position.x + _wall / 2, h, ceiling, _wall, concrete, west
	)
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - _wall / 2, h, ceiling, _wall, concrete, east)
	var x_west := r.position.x + _wall / 2
	var x_east := r.end.x - _wall / 2
	var corridor_mid := (CORRIDOR.x + CORRIDOR.y) / 2.0
	var leaf := (CORRIDOR.y - CORRIDOR.x - _wall) / 2.0
	if is_zero_approx(h):
		for y: float in [r.position.y + _wall / 2, r.end.y - _wall / 2]:
			_builder._door(Vector3(corridor_mid - leaf / 2.0, h, y), 0.0, leaf)
			_builder._door(Vector3(corridor_mid + leaf / 2.0, h, y), 0.0, leaf)
		for doors: Vector2 in [MAIN_DOORS, EMERGENCY_DOORS]:
			var half := (doors.y - doors.x) / 2.0
			_builder._door(Vector3(x_east, h, doors.x + half / 2.0), 90.0, half)
			_builder._door(Vector3(x_east, h, doors.y - half / 2.0), 90.0, half)
		_builder._door(Vector3(x_west, h, PHARMACY_EXIT), -90.0, 1.2, Door.Kind.EMERGENCY)
	elif is_equal_approx(h, LEVELS[-1]):
		_builder._door(
			Vector3(corridor_mid - leaf / 2.0, h, r.end.y - _wall / 2), 0.0, leaf, Door.Kind.FIRE
		)
		_builder._door(
			Vector3(corridor_mid + leaf / 2.0, h, r.end.y - _wall / 2), 0.0, leaf, Door.Kind.FIRE
		)
	if basement:
		var half := (QUAY_DOORS.y - QUAY_DOORS.x) / 2.0
		_builder._door(Vector3(x_west, h, QUAY_DOORS.x + half / 2.0), 90.0, half)
		_builder._door(Vector3(x_west, h, QUAY_DOORS.y - half / 2.0), 90.0, half)


## Window gaps that do not overlap the given spans (doors).
func _clear(gaps: Array, spans: Array) -> Array:
	var kept: Array = []
	for gap: Array in gaps:
		var free := true
		for span: Vector2 in spans:
			if gap[0] < span.y + 0.3 and gap[1] > span.x - 0.3:
				free = false
		if free:
			kept.append(gap)
	return kept


## The floor of a level: a slab under the basement, the ground's own slab
## under the ground floor (a thin ghost layer for the lining), a slab with
## the stair holes under the floors above.
func _floor(s: MapKit.Structure, h: float, material: Material) -> void:
	var inner := RECT.grow(-_wall)
	if h < 0.0:
		kit.box(
			s,
			inner.position.x,
			inner.position.y,
			inner.end.x,
			inner.end.y,
			h - _slab,
			h,
			material,
			MapKit.Kind.FLOOR
		)
		return
	var pieces: Array[Rect2] = [inner]
	var holes: Array[Rect2] = [NORTH_STAIRS, SOUTH_STAIRS]
	if is_equal_approx(h, LEVELS[-1]):
		_top_railings(s, h)
	for hole: Rect2 in holes:
		var next: Array[Rect2] = []
		for piece in pieces:
			next.append_array(MapKit.subtract(piece, hole))
		pieces = next
	for piece in pieces:
		if is_zero_approx(h):
			kit.box(
				s,
				piece.position.x,
				piece.position.y,
				piece.end.x,
				piece.end.y,
				0,
				0.03,
				material,
				MapKit.Kind.GHOST
			)
		else:
			kit.box(
				s,
				piece.position.x,
				piece.position.y,
				piece.end.x,
				piece.end.y,
				h - _slab,
				h,
				material,
				MapKit.Kind.FLOOR
			)


## One side of the corridor on a level: the corridor wall with the rooms'
## doors and openings, and the walls between the rooms.
func _rooms(s: MapKit.Structure, h: float, side: int, rooms: Array) -> void:
	var concrete: Material = _builder.MAT_CONCRETE
	var basement := h < 0.0
	var ceiling: float = -_builder.GROUND_THICKNESS if basement else h + STOREY
	var x := CORRIDOR.x if side < 0 else CORRIDOR.y
	var outer := RECT.position.x if side < 0 else RECT.end.x
	var gaps: Array = []
	var stairs := SOUTH_STAIRS if side < 0 else NORTH_STAIRS
	gaps.append([stairs.position.y, stairs.end.y, ceiling])
	if side > 0:
		gaps.append([LIFT.position.y, LIFT.end.y, ceiling])  # The lift's doors face the corridor.
	for room: Array in rooms:
		var door: Variant = room[2]
		if door is Array:
			gaps.append([door[0], door[1], h + _door_top])
		elif door != null:
			gaps.append([door - 0.6, door + 0.6, h + _door_top])
			_builder._door(Vector3(x, h, door), 90.0, 1.2)
		# The wall between this room and the next one north.
		var y0: float = room[0]
		if y0 > RECT.position.y + 0.1:
			var between: Array = []
			for link: Array in LINKS:
				if is_equal_approx(link[0], h) and link[1] == side and is_equal_approx(link[2], y0):
					between.append([link[3] - 0.6, link[3] + 0.6, h + _door_top])
			kit.wall_x(s, minf(x, outer), maxf(x, outer), y0, h, ceiling, _wall, concrete, between)
	kit.wall_y(s, RECT.position.y, RECT.end.y, x, h, ceiling, _wall, concrete, gaps)


## Two doors across the corridor at y, a lintel above them.
func _fire_doors(s: MapKit.Structure, h: float, y: float) -> void:
	var leaf := (CORRIDOR.y - CORRIDOR.x - _wall) / 2.0
	var mid := (CORRIDOR.x + CORRIDOR.y) / 2.0
	kit.box(
		s,
		CORRIDOR.x,
		y - _wall / 2,
		CORRIDOR.y,
		y + _wall / 2,
		h + _door_top,
		h + STOREY,
		_builder.MAT_CONCRETE
	)
	_builder._door(Vector3(mid - leaf / 2.0, h, y), 0.0, leaf, Door.Kind.FIRE)
	_builder._door(Vector3(mid + leaf / 2.0, h, y), 0.0, leaf, Door.Kind.FIRE)


## The south flight of a stairwell: the one that arrives on the corridor.
func _arriving_flight(hole: Rect2, side: int) -> Rect2:
	var y := hole.position.y + FLIGHT_WIDTH + DIVIDER
	var x := hole.position.x if side > 0 else hole.end.x - FLIGHT_LENGTH
	return Rect2(x, y, FLIGHT_LENGTH, FLIGHT_WIDTH)


## On the top level, nothing goes up: a railing keeps the corridor from the
## open flight below, another one tops the divider along the flight that
## arrives.
func _top_railings(s: MapKit.Structure, h: float) -> void:
	var parapet: float = _builder.PARAPET
	for entry: Array in [[NORTH_STAIRS, 1], [SOUTH_STAIRS, -1]]:
		var hole: Rect2 = entry[0]
		var flight := _arriving_flight(hole, entry[1])
		var near := hole.position.x if entry[1] > 0 else hole.end.x
		var divider := flight.position.y - DIVIDER
		kit.box(
			s,
			flight.position.x,
			divider,
			flight.end.x,
			flight.position.y,
			h,
			h + parapet,
			_builder.MAT_CONCRETE
		)
		kit.wall_y(
			s,
			hole.position.y,
			divider,
			near + entry[1] * 0.1,
			h,
			h + parapet,
			0.2,
			_builder.MAT_CONCRETE
		)


## One storey of switchback stairs in a hole, leaving the corridor on `side`:
## up away from the corridor on the north flight, a mid landing at the far
## end, back to the corridor on the south one.
func _stairs(s: MapKit.Structure, hole: Rect2, side: int, h: float, material: Material) -> void:
	var half := STOREY / 2.0
	var near := hole.position.x if side > 0 else hole.end.x
	var far := near + side * FLIGHT_LENGTH
	var landing_end := hole.end.x if side > 0 else hole.position.x
	var north := Rect2(hole.position.x, hole.position.y, hole.size.x, FLIGHT_WIDTH)
	var south_y := hole.position.y + FLIGHT_WIDTH + DIVIDER
	kit.ramp(s, near, north.position.y, far, north.end.y, h, h + half, true, material)
	kit.box(
		s,
		minf(far, landing_end),
		hole.position.y,
		maxf(far, landing_end),
		hole.end.y,
		h + half - _slab,
		h + half,
		material,
		MapKit.Kind.FLOOR
	)
	kit.ramp(s, far, south_y, near, south_y + FLIGHT_WIDTH, h + half, h + STOREY, true, material)
	kit.box(
		s,
		minf(near, far),
		north.end.y,
		maxf(near, far),
		south_y,
		h,
		h + STOREY,
		_builder.MAT_CONCRETE
	)


## The walls around the two stairwells, from the basement to the top.
func _stairwells(s: MapKit.Structure, concrete: Material) -> void:
	var top: float = LEVELS[-1] + STOREY
	var bottom: float = LEVELS[0]
	# North-east: closed to the south and the east.
	var n := NORTH_STAIRS
	kit.wall_x(s, n.position.x, n.end.x + _wall, n.end.y + _wall / 2, bottom, top, _wall, concrete)
	kit.wall_y(
		s, RECT.position.y, n.end.y + _wall, n.end.x + _wall / 2, bottom, top, _wall, concrete
	)
	# South-west: closed to the north and the west.
	var w := SOUTH_STAIRS
	kit.wall_x(
		s, w.position.x - _wall, w.end.x, w.position.y - _wall / 2, bottom, top, _wall, concrete
	)
	kit.wall_y(
		s, w.position.y - _wall, RECT.end.y, w.position.x - _wall / 2, bottom, top, _wall, concrete
	)


## The quay of the morgue: the ramp down the service alley, the apron at
## the doors, a retaining wall on the fence side and a parapet around.
func _quay(s: MapKit.Structure, concrete: Material) -> void:
	var low: float = LEVELS[0]
	var ramp := QUAY_RAMP
	var apron := QUAY_APRON
	kit.ramp(
		s,
		ramp.position.x,
		ramp.position.y,
		ramp.end.x,
		ramp.end.y,
		0.0,
		low,
		false,
		_builder.MAT_ASPHALT
	)
	kit.box(
		s,
		apron.position.x,
		apron.position.y,
		apron.end.x,
		apron.end.y,
		low - _slab,
		low,
		_builder.MAT_ASPHALT,
		MapKit.Kind.FLOOR
	)
	var parapet: float = _builder.PARAPET
	kit.wall_y(s, ramp.position.y, apron.end.y, ALLEY_X - _wall / 2, low, parapet, _wall, concrete)
	kit.wall_x(
		s, ALLEY_X - _wall, RECT.position.x, apron.end.y + _wall / 2, low, parapet, _wall, concrete
	)


## The canopy over the emergency entrance: a slab on two posts.
func _canopy(s: MapKit.Structure, concrete: Material) -> void:
	var c := CANOPY
	kit.box(
		s,
		c.position.x,
		c.position.y,
		c.end.x,
		c.end.y,
		CANOPY_HEIGHT,
		CANOPY_HEIGHT + 0.3,
		concrete,
		MapKit.Kind.GHOST
	)
	for y: float in [c.position.y + 0.5, c.end.y - 0.5]:
		kit.box(s, c.end.x - 0.6, y - 0.2, c.end.x - 0.2, y + 0.2, 0.0, CANOPY_HEIGHT, concrete)


## Metal stairs on the south front, from the 2nd floor's corridor door down
## to the ground: a landing, a flight east, a mid landing, a flight back west.
func _fire_escape(s: MapKit.Structure) -> void:
	var metal: Material = _builder._material("metal")
	var top: float = LEVELS[-1]
	var mid := top - STOREY
	var parapet: float = _builder.PARAPET
	var l := ESCAPE_LANDING
	kit.box(
		s, l.position.x, l.position.y, l.end.x, l.end.y, top - _slab, top, metal, MapKit.Kind.FLOOR
	)
	kit.wall_y(s, l.position.y, l.end.y, l.position.x - 0.05, top, top + parapet, 0.1, metal)
	var a := ESCAPE_TOP
	kit.ramp(s, a.position.x, a.position.y, a.end.x, a.end.y, top, mid, true, metal)
	var m := ESCAPE_MID
	kit.box(
		s, m.position.x, m.position.y, m.end.x, m.end.y, mid - _slab, mid, metal, MapKit.Kind.FLOOR
	)
	kit.wall_y(s, m.position.y, m.end.y, m.end.x + 0.05, mid, mid + parapet, 0.1, metal)
	var b := ESCAPE_BOTTOM
	kit.ramp(s, b.end.x, b.position.y, b.position.x, b.end.y, mid, 0.0, true, metal)
	# Railings: between the flights, along the outer side.
	kit.wall_x(s, l.position.x, m.position.x, a.end.y + 0.1, mid, top + parapet, 0.1, metal)
	kit.wall_x(s, l.end.x, m.end.x, b.end.y + 0.05, 0.0, mid + parapet, 0.1, metal)
	var floor_box := MetalFloor.new()
	floor_box.name = "HospitalEscapeMetal"
	var area := l.merge(a).merge(b).merge(m)
	floor_box.size = Vector3(area.size.x, top + 2.0, area.size.y)
	floor_box.position = kit.world(
		area.get_center().x, area.get_center().y, floor_box.size.y / 2.0 - 1.0
	)
	_builder._metal_floors.append(floor_box)
