extends "res://tools/godot/tilleuls_tower.gd"
## Social centre, gallery, car park, garages and landmarks (spec S-006,
## S-016), for the cité's generator. See tilleuls_layout.gd for the chain of
## files.


func _build_social_centre() -> void:
	var s := kit.structure("SocialCentre")
	var r := SOCIAL_CENTRE
	var h := SOCIAL_CENTRE_HEIGHT
	var hall_east := 160.0
	var office_west := 163.0
	var kitchen := CENTRE_KITCHEN
	# Outer walls (S-016, Q4): entrances north (corridor) and west (great hall),
	# the emergency exit at the south end of the corridor, the kitchen's back
	# door, windows.
	var north := CENTRE_NORTH_DOORS
	var west := CENTRE_WEST_DOORS
	var exit := CENTRE_EMERGENCY_EXIT
	var back := CENTRE_KITCHEN_DOOR
	kit.wall_x(
		s,
		r.position.x,
		r.end.x,
		r.position.y + WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[
			[north.x, north.y, DOOR_TOP],
			[144.0, 146.0, 2.4, 1.0],
			[150.0, 152.0, 2.4, 1.0],
			[166.0, 168.0, 2.4, 1.0],
			[172.0, 174.0, 2.4, 1.0]
		]
	)
	kit.wall_x(
		s,
		r.position.x,
		r.end.x,
		r.end.y - WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[
			[144.0, 146.0, 2.4, 1.0],
			[152.0, 154.0, 2.4, 1.0],
			[back.x, back.y, DOOR_TOP],
			[exit.x, exit.y, DOOR_TOP],
			[168.0, 170.0, 2.4, 1.0]
		]
	)
	kit.wall_y(
		s,
		r.position.y,
		r.end.y,
		r.position.x + WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[west.x, west.y, DOOR_TOP]]
	)
	kit.wall_y(
		s,
		r.position.y,
		r.end.y,
		r.end.x - WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[64.0, 65.5, 2.4, 1.0], [72.0, 73.5, 2.4, 1.0], [80.0, 81.5, 2.4, 1.0]]
	)
	kit.box(
		s,
		r.position.x,
		r.position.y,
		r.end.x,
		r.end.y,
		h,
		h + SLAB,
		MAT_OBSTACLE,
		MapKit.Kind.FLOOR
	)
	_double_door(
		Vector3((north.x + north.y) / 2.0, 0, r.position.y + WALL / 2), 0.0, north.y - north.x
	)
	_double_door(
		Vector3(r.position.x + WALL / 2, 0, (west.x + west.y) / 2.0), 90.0, west.y - west.x
	)
	_door(
		Vector3((exit.x + exit.y) / 2.0, 0, r.end.y - WALL / 2),
		0.0,
		exit.y - exit.x,
		Door.Kind.EMERGENCY
	)
	_door(Vector3((back.x + back.y) / 2.0, 0, r.end.y - WALL / 2), 0.0, back.y - back.x)
	# Great hall and corridor, double doors between them.
	var hall_doors := [Vector2(66.0, 68.0), Vector2(73.0, 75.0)]
	var hall_gaps: Array = []
	for d: Vector2 in hall_doors:
		hall_gaps.append([d.x, d.y, DOOR_TOP])
		_double_door(Vector3(hall_east, 0, (d.x + d.y) / 2.0), 90.0, d.y - d.x)
	hall_gaps.append([80.0, 81.2, DOOR_TOP])  # The kitchen, from the corridor.
	_door(Vector3(hall_east, 0, 80.6), 90.0, 1.2)
	kit.wall_y(s, r.position.y, r.end.y, hall_east, 0, h, WALL, MAT_CONCRETE, hall_gaps)
	# Offices along the corridor, each with its door, and a door between
	# neighbours: no dead end (Q4).
	var office_gaps: Array = []
	for y: float in [63.0, 71.0, 79.0]:
		office_gaps.append([y, y + 1.2, DOOR_TOP])
		_door(Vector3(office_west, 0, y + 0.6), 90.0, 1.2)
	kit.wall_y(s, r.position.y, r.end.y, office_west, 0, h, WALL, MAT_CONCRETE, office_gaps)
	for y: float in [68.0, 76.0]:
		kit.wall_x(s, office_west, r.end.x, y, 0, h, WALL, MAT_CONCRETE, [[172.0, 173.2, DOOR_TOP]])
		_door(Vector3(172.6, 0, y), 0.0, 1.2)
	# The kitchen, south-east of the great hall: a door to the hall, a hatch
	# over the counter.
	kit.wall_x(
		s,
		kitchen.position.x,
		kitchen.end.x,
		kitchen.position.y,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[154.0, 156.4, 2.0, 1.0]]
	)
	kit.wall_y(
		s,
		kitchen.position.y,
		r.end.y,
		kitchen.position.x,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[80.0, 81.2, DOOR_TOP]]
	)
	_door(Vector3(kitchen.position.x, 0, 80.6), 90.0, 1.2)
	kit.box(
		s,
		154.0,
		kitchen.position.y + WALL / 2,
		156.4,
		kitchen.position.y + 0.8,
		0,
		1.0,
		MAT_OBSTACLE,
		MapKit.Kind.FLOOR
	)
	# The stage, west of the hall, its wings behind a curtain.
	var stage := CENTRE_STAGE
	kit.box(
		s,
		stage.position.x,
		stage.position.y,
		stage.end.x,
		stage.end.y,
		0,
		0.6,
		MAT_OBSTACLE,
		MapKit.Kind.FLOOR
	)
	# The chair store, to run around (S-020, T-341, C2).
	var store := CENTRE_CHAIR_STORE
	kit.box(
		s,
		store.position.x,
		store.position.y,
		store.end.x,
		store.end.y,
		0,
		CENTRE_CHAIR_STORE_HEIGHT,
		MAT_CONCRETE
	)
	# Tables in the hall, desks in the offices (the stacked chairs: FURNITURE).
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
	var corridor := Vector2(back + 0.2, r.end.y - 0.3)
	# Arcade roof on pillars.
	kit.box(
		s, r.position.x, r.position.y, r.end.x, front, h - SLAB, h, MAT_OBSTACLE, MapKit.Kind.FLOOR
	)
	var x := r.position.x + 0.3
	while x < r.end.x:
		kit.box(
			s, x - 0.2, r.position.y + 0.1, x + 0.2, r.position.y + 0.5, 0, h - SLAB, MAT_CONCRETE
		)
		x += width
	kit.box(
		s,
		r.end.x - 0.5,
		r.position.y + 0.1,
		r.end.x - 0.1,
		r.position.y + 0.5,
		0,
		h - SLAB,
		MAT_CONCRETE
	)
	# Shop fronts (S-016): the pharmacy's door, the laundrette's double door,
	# the tobacconist's shutter to roll up, the grocer's shutter half down, the
	# baker's door with its bell.
	var fronts: Array = []
	for i in GALLERY_SHOPS:
		var gap: Vector2 = GALLERY_FRONTS[i]
		var top := SHUTTER_TOP if i == GALLERY_HALF_SHUTTER else DOOR_TOP
		fronts.append([gap.x, gap.y, top])
	kit.wall_x(s, r.position.x, r.end.x, front, 0, h, WALL, MAT_CONCRETE, fronts)
	var mid := func(i: int) -> Vector3:
		return Vector3((GALLERY_FRONTS[i].x + GALLERY_FRONTS[i].y) / 2.0, 0, front)
	var span := func(i: int) -> float: return GALLERY_FRONTS[i].y - GALLERY_FRONTS[i].x
	_door(mid.call(0), 0.0, span.call(0))
	_double_door(mid.call(1), 0.0, span.call(1))
	_door(mid.call(2), 0.0, span.call(2), Door.Kind.SHUTTER)
	_door(mid.call(4), 0.0, span.call(4), Door.Kind.NORMAL, true)
	# Back wall, east and west walls, roof. The delivery corridor opens at
	# both ends: a fire door east, an emergency exit west (Q4).
	var window := GALLERY_VAULT_WINDOW  # Broken, to climb over (S-020, T-340, F3).
	kit.wall_x(
		s,
		r.position.x,
		r.end.x,
		r.end.y - WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[window.x, window.y, WINDOW_TOP, WINDOW_SILL]]
	)
	kit.wall_y(
		s,
		front,
		r.end.y,
		r.position.x + WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[corridor.x, corridor.y, DOOR_TOP]]
	)
	kit.wall_y(
		s,
		front,
		r.end.y,
		r.end.x - WALL / 2,
		0,
		h,
		WALL,
		MAT_CONCRETE,
		[[corridor.x, corridor.y, DOOR_TOP]]
	)
	var corridor_mid := (corridor.x + corridor.y) / 2.0
	_door(
		Vector3(r.end.x - WALL / 2, 0, corridor_mid), 90.0, corridor.y - corridor.x, Door.Kind.FIRE
	)
	_door(
		Vector3(r.position.x + WALL / 2, 0, corridor_mid),
		-90.0,
		corridor.y - corridor.x,
		Door.Kind.EMERGENCY
	)
	kit.box(s, r.position.x, front, r.end.x, r.end.y, h, h + SLAB, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# Shops side by side, each with a back door onto the corridor; a door
	# between the grocer's and the baker's stockrooms.
	for i in range(1, GALLERY_SHOPS):
		var gaps: Array = []
		if i == GALLERY_SHOPS - 1:
			gaps.append([144.5, 145.7, DOOR_TOP])
			_door(Vector3(r.position.x + i * width, 0, 145.1), 90.0, 1.2)
		kit.wall_y(s, front, back, r.position.x + i * width, 0, h, WALL, MAT_CONCRETE, gaps)
	var back_doors: Array = []
	for i in GALLERY_SHOPS:
		var at := r.position.x + i * width + 5.5
		back_doors.append([at, at + 1.2, DOOR_TOP])
		_door(Vector3(at + 0.6, 0, back), 0.0, 1.2)
	kit.wall_x(s, r.position.x, r.end.x, back, 0, h, WALL, MAT_CONCRETE, back_doors)
	# Washing machines along the laundrette walls.
	var laundrette := r.position.x + width
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		kit.box(s, mx - 0.6, back - 1.0, mx + 0.6, back - 0.2, 0, 0.9, null, MapKit.Kind.FLOOR)
	# Counters and shelves: FURNITURE (T-241).
	_gallery_roof_stairs(s)


## Two steep metal flights up to the roof (S-016, Q4: they stand for the
## ladders), one behind the back wall, one along the east wall.
func _gallery_roof_stairs(s: MapKit.Structure) -> void:
	var r := GALLERY
	var metal := _material("metal")
	var roof := GALLERY_HEIGHT + SLAB
	var w := GALLERY_ROOF_STAIR_WIDTH
	# Behind: rising east along the back wall, a landing onto the roof.
	var b := GALLERY_BACK_STAIRS
	kit.ramp(s, b.x, r.end.y, b.y, r.end.y + w, 0, roof, true, metal)
	kit.box(s, b.y, r.end.y, b.y + 1.5, r.end.y + w, roof - SLAB, roof, metal, MapKit.Kind.FLOOR)
	kit.wall_x(s, b.x, b.y + 1.5, r.end.y + w + 0.05, 0, roof + PARAPET, 0.1, metal)
	_metal_floor("GalleryBackStairs", Rect2(b.x, r.end.y, b.y + 1.5 - b.x, w), roof)
	# East: rising south along the east wall, a landing onto the roof.
	var e := GALLERY_EAST_STAIRS
	kit.ramp(s, r.end.x, e.x, r.end.x + w, e.y, 0, roof, false, metal)
	kit.box(s, r.end.x, e.y, r.end.x + w, e.y + 1.5, roof - SLAB, roof, metal, MapKit.Kind.FLOOR)
	kit.wall_y(s, e.x, e.y + 1.5, r.end.x + w + 0.05, 0, roof + PARAPET, 0.1, metal)
	_metal_floor("GalleryEastStairs", Rect2(r.end.x, e.x, w, e.y + 1.5 - e.x), roof)


func _build_car_park() -> void:
	var s := kit.structure("CarPark")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ramp := CAR_PARK_RAMP
	var stairs := CAR_PARK_STAIRS
	kit.box(
		s,
		r.position.x,
		r.position.y,
		r.end.x,
		r.end.y,
		floor_h - SLAB,
		floor_h,
		MAT_ASPHALT,
		MapKit.Kind.FLOOR
	)
	# Retaining walls; the ramp comes in through the west one.
	var ceiling := -GROUND_THICKNESS
	kit.wall_x(
		s, r.position.x, r.end.x, r.position.y + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE
	)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(
		s,
		r.position.y,
		r.end.y,
		r.position.x + WALL / 2,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE,
		[
			[CELLAR_CORRIDOR.position.y, CELLAR_CORRIDOR.end.y, ceiling],
			[ramp.position.y, ramp.end.y, ceiling]
		]
	)
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	# Pillars every 8 m.
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			kit.box(s, px - 0.25, py - 0.25, px + 0.25, py + 0.25, floor_h, ceiling, MAT_CONCRETE)
		px += CAR_PARK_PILLAR_STEP
	# Car ramp from the ground down to the car park, with its side walls.
	kit.ramp(
		s, ramp.position.x, ramp.position.y, ramp.end.x, ramp.end.y, 0, floor_h, true, MAT_ASPHALT
	)
	kit.wall_x(
		s,
		ramp.position.x,
		ramp.end.x,
		ramp.position.y - WALL / 2,
		floor_h,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_x(
		s, ramp.position.x, ramp.end.x, ramp.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE
	)
	# Emergency stairs up to the slab in the south-east corner, a railing around them.
	kit.ramp(
		s,
		stairs.position.x,
		stairs.position.y,
		stairs.end.x,
		stairs.end.y,
		floor_h,
		0,
		true,
		MAT_OBSTACLE
	)
	kit.wall_x(
		s,
		stairs.position.x - WALL,
		stairs.end.x,
		stairs.position.y - WALL / 2,
		floor_h,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_x(
		s,
		stairs.position.x - WALL,
		stairs.end.x,
		stairs.end.y + WALL / 2,
		floor_h,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_y(
		s,
		stairs.position.y,
		stairs.end.y,
		stairs.position.x - WALL / 2,
		0,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	# North stairs (S-016): from the ground at their west end down to the
	# floor, closed under the flight, a railing around the hole, a fire door
	# at their foot.
	var north := CAR_PARK_NORTH_STAIRS
	kit.ramp(
		s,
		north.position.x,
		north.position.y,
		north.end.x,
		north.end.y,
		0,
		floor_h,
		true,
		MAT_OBSTACLE
	)
	kit.wall_x(
		s,
		north.position.x,
		north.end.x + WALL,
		north.end.y + WALL / 2,
		floor_h,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_x(
		s,
		north.position.x,
		north.end.x + WALL,
		north.position.y - WALL / 2,
		0,
		PARAPET,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_y(
		s, north.position.y, north.end.y, north.end.x + WALL / 2, 0, PARAPET, WALL, MAT_CONCRETE
	)
	kit.wall_y(
		s,
		north.position.y,
		north.end.y,
		north.position.x - WALL / 2,
		floor_h,
		-GROUND_THICKNESS,
		WALL,
		MAT_CONCRETE
	)
	kit.wall_y(
		s,
		north.position.y - WALL,
		north.end.y + WALL,
		north.end.x + WALL / 2,
		floor_h + DOOR_TOP,
		ceiling,
		WALL,
		MAT_CONCRETE
	)
	_double_door(
		Vector3(north.end.x + WALL / 2, floor_h, north.get_center().y),
		90.0,
		north.size.y,
		Door.Kind.FIRE
	)
	# The technical room, east, with its door.
	var room := CAR_PARK_TECHNICAL
	var room_door := [[104.0, 105.2, floor_h + DOOR_TOP]]
	var north_door := CAR_PARK_TECHNICAL_NORTH_DOOR  # A loop through the room (T-341).
	kit.wall_x(
		s,
		room.position.x,
		room.end.x,
		room.position.y,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE,
		[[north_door.x, north_door.y, floor_h + DOOR_TOP]]
	)
	_door(Vector3((north_door.x + north_door.y) / 2.0, floor_h, room.position.y), 0.0, 1.2)
	kit.wall_x(s, room.position.x, room.end.x, room.end.y, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(
		s,
		room.position.y,
		room.end.y,
		room.position.x,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE,
		room_door
	)
	_door(Vector3(room.position.x, floor_h, 104.6), 90.0, 1.2)
	# Parked wrecks to hide behind.
	for c: Vector2 in CAR_PARK_WRECKS:
		kit.box(
			s,
			c.x - 1.0,
			c.y - 2.1,
			c.x + 1.0,
			c.y + 2.1,
			floor_h,
			floor_h + 1.3,
			null,
			MapKit.Kind.FLOOR
		)
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
	kit.box(
		s, r.position.x, r.position.y, r.end.x, r.end.y, h, h + 0.2, MAT_OBSTACLE, MapKit.Kind.FLOOR
	)
	var doors: Array = []
	for i in GARAGE_COUNT:
		var y0 := r.position.y + i * width
		if i > 0:
			kit.wall_x(s, r.position.x, r.end.x, y0, 0, h, WALL, MAT_CONCRETE)
		if GARAGES_OPEN.has(i):
			doors.append([y0 + 0.5, y0 + width - 0.5, DOOR_TOP])
			# Junk inside: a workbench and boxes.
			kit.box(
				s,
				r.position.x + 0.4,
				y0 + 0.6,
				r.position.x + 2.0,
				y0 + 2.2,
				0,
				1.0,
				MAT_OBSTACLE,
				MapKit.Kind.FLOOR
			)
	kit.wall_y(
		s, r.position.y, r.end.y, r.end.x - WALL / 2, 0, h, WALL, _material("garage_door"), doors
	)


# --- Outdoor landmarks ------------------------------------------------------


func _build_landmarks() -> void:
	_build_playground()
	_build_city_stadium()
	var transformer := kit.structure("Transformer")
	kit.box(transformer, 96, 150, 105, 157, 0, 2.6, null)  # Dressed by its model (T-048).


func _build_playground() -> void:
	var s := kit.structure("Playground")
	var low := MapKit.Kind.FLOOR
	# Low wall around the sand, with a way in on the north and the south sides.
	# Too high for the navigation mesh to climb (T-060): a kerb the bodies cannot
	# step over, but the mesh could, held the AI prey against it for good.
	var kerb := 0.5
	for y: Array in [[70.0, 70.3], [91.7, 92.0]]:
		kit.box(s, 50, y[0], 60, y[1], 0, kerb, MAT_OBSTACLE, low)
		kit.box(s, 61.6, y[0], 72, y[1], 0, kerb, MAT_OBSTACLE, low)
	kit.box(s, 50, 70.3, 50.3, 91.7, 0, kerb, MAT_OBSTACLE, low)
	kit.box(s, 71.7, 70.3, 72, 91.7, 0, kerb, MAT_OBSTACLE, low)
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
