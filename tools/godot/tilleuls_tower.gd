extends "res://tools/godot/tilleuls_base.gd"
## Ground, borders, blocks of flats, the tower and its cellars (spec S-006,
## S-016, S-018), for the cité's generator. See tilleuls_layout.gd for the
## chain of files.


func _build_ground() -> void:
	var holes: Array[Rect2] = [CAR_PARK_RAMP, CAR_PARK_STAIRS, CAR_PARK_NORTH_STAIRS, CELLAR_STAIRS]
	holes.append_array(Hospital.ground_holes())
	kit.slab_tiles(
		"Tile",
		Rect2(0, 0, MAP_SIZE, MAP_SIZE),
		holes,
		-GROUND_THICKNESS,
		0.0,
		MAT_DIRT,
		GROUND_TILE
	)
	var roads := kit.structure("Paths", "Ground")
	for line: Array in PATHS:
		for i in line.size() - 1:
			_path_segment(roads, line[i], line[i + 1])
	# Outside the fences: the motorway to the east, the boulevard to the south.
	kit.box(roads, 211, 10, 220, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)
	kit.box(roads, 0, 213, 211, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


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
	kit.box(
		s, r.position.x, r.position.y, r.end.x, r.end.y, top, TOWER_STOREYS * STOREY, MAT_CONCRETE
	)
	for level in TOWER_VISITED_STOREYS:
		var h := level * STOREY
		var windows: Array = [] if level == 0 else _windows(r.position.x, r.end.x, h)
		# Outer walls: double doors north and south on the ground floor (S-016).
		var north_gaps: Array = (
			[[TOWER_NORTH_DOORS.x, TOWER_NORTH_DOORS.y, DOOR_TOP]] if level == 0 else windows
		)
		var south_gaps: Array = (
			[[TOWER_SOUTH_DOORS.x, TOWER_SOUTH_DOORS.y, DOOR_TOP]] if level == 0 else windows
		)
		kit.wall_x(
			s,
			r.position.x,
			r.end.x,
			r.position.y + WALL / 2,
			h,
			h + STOREY,
			WALL,
			MAT_CONCRETE,
			north_gaps
		)
		kit.wall_x(
			s,
			r.position.x,
			r.end.x,
			r.end.y - WALL / 2,
			h,
			h + STOREY,
			WALL,
			MAT_CONCRETE,
			south_gaps
		)
		var side: Array = [] if level == 0 else _windows(r.position.y, r.end.y, h)
		kit.wall_y(
			s,
			r.position.y,
			r.end.y,
			r.position.x + WALL / 2,
			h,
			h + STOREY,
			WALL,
			MAT_CONCRETE,
			side + ([_tower_vault_gap()] if level == 0 else [])
		)
		# East: the fire escape door at the end of each corridor (S-016, Q4).
		var east_gaps := side.duplicate()
		if level > 0:
			east_gaps.append([FIRE_ESCAPE_DOOR.x, FIRE_ESCAPE_DOOR.y, h + DOOR_TOP])
		kit.wall_y(
			s,
			r.position.y,
			r.end.y,
			r.end.x - WALL / 2,
			h,
			h + STOREY,
			WALL,
			MAT_CONCRETE,
			east_gaps
		)
		# Floor: the ground floor stands on the ground, the others have a hole for the stairs.
		if level > 0:
			for piece in MapKit.subtract(inner, hole):
				kit.box(
					s,
					piece.position.x,
					piece.position.y,
					piece.end.x,
					piece.end.y,
					h - SLAB,
					h,
					MAT_OBSTACLE,
					MapKit.Kind.FLOOR
				)
		else:
			for piece in MapKit.subtract(inner, CELLAR_STAIRS):
				kit.box(
					s,
					piece.position.x,
					piece.position.y,
					piece.end.x,
					piece.end.y,
					0,
					0.03,
					MAT_OBSTACLE,
					MapKit.Kind.GHOST
				)
		_tower_stairs(s, h, level == TOWER_VISITED_STOREYS - 1)
		# On each storey, a double fire door across the corridor on either side
		# of the stair landing (Q3), a lintel above it.
		if level > 0:
			for x: float in [STAIR_X - WALL / 2, east + WALL / 2]:
				var leaf := (CORRIDOR.y - CORRIDOR.x) / 2.0
				kit.box(
					s,
					x - WALL / 2,
					CORRIDOR.x,
					x + WALL / 2,
					CORRIDOR.y,
					h + DOOR_TOP,
					h + STOREY,
					MAT_CONCRETE
				)
				_door(Vector3(x, h, CORRIDOR.x + leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
				_door(Vector3(x, h, CORRIDOR.y - leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
		if level == 0:
			_tower_ground_floor(s)
		else:
			_tower_flats(s, h)
			_door(
				Vector3(r.end.x - WALL / 2, h, (FIRE_ESCAPE_DOOR.x + FIRE_ESCAPE_DOOR.y) / 2.0),
				90.0,
				FIRE_ESCAPE_DOOR.y - FIRE_ESCAPE_DOOR.x,
				Door.Kind.FIRE
			)
	# Stairwell walls, west, east and north, from the ground to the top.
	kit.wall_y(
		s, stair_north - WALL, STAIR_LANDING_Y, STAIR_X - WALL / 2, 0, top, WALL, MAT_CONCRETE
	)
	kit.wall_y(s, stair_north - WALL, STAIR_LANDING_Y, east + WALL / 2, 0, top, WALL, MAT_CONCRETE)
	kit.wall_x(s, STAIR_X - WALL, east + WALL, stair_north - WALL / 2, 0, top, WALL, MAT_CONCRETE)
	# The lift shaft, beside the stairs, from the ground to the top: its cabin
	# is stuck on the ground floor (a hiding spot, S-016).
	kit.box(
		s,
		LIFT_SHAFT.position.x,
		LIFT_SHAFT.position.y,
		LIFT_SHAFT.end.x,
		LIFT_SHAFT.end.y,
		0,
		top,
		MAT_CONCRETE
	)
	_tower_fire_escape(s)
	var beacon := _material("beacon")
	var c := r.get_center()
	kit.box(
		s,
		c.x - 0.3,
		c.y - 0.3,
		c.x + 0.3,
		c.y + 0.3,
		TOWER_STOREYS * STOREY,
		TOWER_STOREYS * STOREY + 0.6,
		beacon,
		MapKit.Kind.GHOST
	)


## One storey of stairs: flight up to the north, mid landing, flight back south.
## On the last visitable storey a grille closes the way up (Q4).
func _tower_stairs(s: MapKit.Structure, h: float, last: bool) -> void:
	_switchback(s, STAIR_X, h, MAT_OBSTACLE, MAT_CONCRETE)
	if last:
		var west_end := STAIR_X + STAIR_FLIGHT_WIDTH
		kit.box(
			s,
			STAIR_X,
			STAIR_LANDING_Y - 0.15,
			west_end,
			STAIR_LANDING_Y,
			h,
			h + STOREY,
			_material("grille")
		)


## Ground floor (S-016): a hall through the tower, the stairs down to the
## cellars where the technical room was, the bin room, the stuck lift.
## The broken window of the hall to climb over (S-020, T-340, F6), where the
## storeys above have theirs.
func _tower_vault_gap() -> Array:
	return [TOWER_VAULT_WINDOW.x, TOWER_VAULT_WINDOW.y, WINDOW_TOP, WINDOW_SILL]


func _tower_ground_floor(s: MapKit.Structure) -> void:
	var r := TOWER
	# Double doors north and south.
	for doors: Vector2 in [TOWER_NORTH_DOORS, TOWER_SOUTH_DOORS]:
		var y := r.position.y + WALL / 2 if doors == TOWER_NORTH_DOORS else r.end.y - WALL / 2
		var leaf := (doors.y - doors.x) / 2.0
		_door(Vector3(doors.x + leaf / 2.0, 0, y), 0.0, leaf)
		_door(Vector3(doors.y - leaf / 2.0, 0, y), 0.0, leaf)
	# Cellar stairs room, north-west: a fire door from the hall.
	var door := CELLAR_DOOR
	kit.wall_y(
		s,
		r.position.y,
		STAIR_LANDING_Y,
		99.0,
		0,
		STOREY,
		WALL,
		MAT_CONCRETE,
		[[door.x, door.y, DOOR_TOP]]
	)
	kit.wall_x(s, r.position.x, 99.0, STAIR_LANDING_Y, 0, STOREY, WALL, MAT_CONCRETE)
	_door(Vector3(99.0, 0, (door.x + door.y) / 2.0), 90.0, door.y - door.x, Door.Kind.FIRE)
	# A railing along the open side of the stairs, but at their top.
	var c := CELLAR_STAIRS
	kit.wall_x(
		s, c.position.x + CELLAR_LANDING, c.end.x, c.position.y - 0.1, 0, PARAPET, 0.2, MAT_CONCRETE
	)
	kit.wall_y(s, c.position.y - 0.2, c.end.y, c.end.x + 0.1, 0, PARAPET, 0.2, MAT_CONCRETE)
	# Bin room, south-west, with its door.
	kit.wall_x(
		s, r.position.x, 99.0, 104.0, 0, STOREY, WALL, MAT_CONCRETE, [[95.0, 96.2, DOOR_TOP]]
	)
	_door(Vector3(95.6, 0, 104.0), 0.0, 1.2)
	kit.wall_y(s, 104.0, r.end.y, 99.0, 0, STOREY, WALL, MAT_CONCRETE)
	# Letter boxes along the east wall of the hall.
	kit.box(s, 114.6, 92.0, 115.7, 97.0, 0.8, 1.8, MAT_OBSTACLE, MapKit.Kind.FLOOR)


## Flats around the corridor (S-016): all four open on every storey, each
## behind its door, with two or three rooms; a hole in the partition joins
## the two south flats, low enough to crawl through.
func _tower_flats(s: MapKit.Structure, h: float) -> void:
	var r := TOWER
	var top := h + STOREY
	var north := CORRIDOR.x
	var south := CORRIDOR.y
	var stair_east := STAIR_X + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var gap := func(at: float) -> Array: return [[at, at + DOOR_WIDTH, h + DOOR_TOP]]
	# Front doors: 0 north-west, 1 north-east, 2 south-west, 3 south-east.
	var fronts := [[97.0, north], [108.0, north], [98.5, south], [106.0, south]]
	kit.wall_x(s, r.position.x, STAIR_X - WALL, north, h, top, WALL, MAT_CONCRETE, gap.call(97.0))
	kit.wall_x(s, stair_east + WALL, r.end.x, north, h, top, WALL, MAT_CONCRETE, gap.call(108.0))
	kit.wall_x(s, r.position.x, 104.0, south, h, top, WALL, MAT_CONCRETE, gap.call(98.5))
	kit.wall_x(s, 104.0, r.end.x, south, h, top, WALL, MAT_CONCRETE, gap.call(106.0))
	for front: Array in fronts:
		_door(Vector3(front[0] + DOOR_WIDTH / 2.0, h, front[1]), 0.0, DOOR_WIDTH)
	# Between the south flats, a hole to crawl through (Q4).
	var crawl := TOWER_CRAWL_HOLE
	kit.wall_y(
		s,
		south,
		r.end.y,
		104.0,
		h,
		top,
		WALL,
		MAT_CONCRETE,
		[[crawl.x, crawl.y, h + TOWER_CRAWL_HEIGHT]]
	)
	# North flats end at the stairwell.
	kit.wall_y(s, r.position.y, north, STAIR_X - WALL / 2, h, top, WALL, MAT_CONCRETE)
	kit.wall_y(s, r.position.y, north, stair_east + WALL / 2, h, top, WALL, MAT_CONCRETE)
	# Inside each flat, a partition with a doorway between two rooms, and a
	# bathroom wall in the south flats.
	kit.wall_y(
		s, r.position.y, north, 96.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]]
	)
	kit.wall_y(
		s, r.position.y, north, 111.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]]
	)
	kit.wall_x(
		s, r.position.x, 104.0, 107.0, h, top, WALL, MAT_CONCRETE, [[100.0, 101.2, h + DOOR_TOP]]
	)
	kit.wall_x(s, 104.0, r.end.x, 107.0, h, top, WALL, MAT_CONCRETE, [[107.0, 108.2, h + DOOR_TOP]])
	kit.wall_y(s, 107.0, r.end.y, 98.0, h, top, WALL, MAT_CONCRETE, [[108.0, 109.2, h + DOOR_TOP]])
	kit.wall_y(s, 107.0, r.end.y, 110.0, h, top, WALL, MAT_CONCRETE, [[108.0, 109.2, h + DOOR_TOP]])


## Metal stairs outside the east wall, from the ground to the 4th storey
## (S-016, Q4 and Q9), with a landing at each corridor door.
func _tower_fire_escape(s: MapKit.Structure) -> void:
	var metal := _material("metal")
	var x0 := TOWER.end.x + 0.3
	var east := x0 + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var landing_south := CORRIDOR.y
	var north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH - STAIR_MID_LANDING
	for level in TOWER_VISITED_STOREYS:
		var h := level * STOREY
		if level > 0:
			kit.box(
				s,
				TOWER.end.x,
				STAIR_LANDING_Y,
				east,
				landing_south,
				h - SLAB,
				h,
				metal,
				MapKit.Kind.FLOOR
			)
			kit.wall_x(s, x0, east, landing_south + 0.05, h, h + PARAPET, 0.1, metal)
		if level < TOWER_VISITED_STOREYS - 1:
			_switchback(s, x0, h, metal, metal)
		# Railings on the outer sides of the flights.
		kit.wall_y(
			s,
			north,
			landing_south,
			east + 0.05,
			h,
			h + STOREY if level < TOWER_VISITED_STOREYS - 1 else h + PARAPET,
			0.1,
			metal
		)
		kit.wall_x(s, x0, east, north - 0.05, h, h + PARAPET + STOREY / 2.0, 0.1, metal)
	var floor_box := MetalFloor.new()
	floor_box.name = "FireEscapeMetal"
	floor_box.size = Vector3(
		east - TOWER.end.x, TOWER_VISITED_STOREYS * STOREY + 2.0, landing_south - north
	)
	floor_box.position = kit.world(
		(TOWER.end.x + east) / 2.0, (north + landing_south) / 2.0, floor_box.size.y / 2.0 - 1.0
	)
	_metal_floors.append(floor_box)


## The cellars (S-016, Q5): stairs down from the tower's ground floor, then a
## corridor under the street to the car park, a fire door at each end, the
## cellar cages along it.
func _build_cellars() -> void:
	var s := kit.structure("Cellars")
	var c := CELLAR_STAIRS
	var corridor := CELLAR_CORRIDOR
	var floor_h := -CAR_PARK_DEPTH
	var ceiling := -GROUND_THICKNESS
	# Stairs down from the west (top) to the east (bottom), in their shaft,
	# after a flat landing at the top: turning onto a slope at once, an AI
	# body caught on the shaft's edge there and stayed (T-243).
	var landing := c.position.x + CELLAR_LANDING
	kit.box(
		s, c.position.x, c.position.y, landing, c.end.y, -SLAB, 0, MAT_OBSTACLE, MapKit.Kind.FLOOR
	)
	kit.ramp(s, landing, c.position.y, c.end.x, c.end.y, 0, floor_h, true, MAT_OBSTACLE)
	kit.wall_x(
		s, c.position.x, c.end.x, c.position.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE
	)
	kit.wall_y(
		s,
		c.position.y - WALL,
		corridor.end.y + WALL,
		c.position.x - WALL / 2,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE
	)
	# The corridor, from the foot of the stairs to the car park.
	kit.box(
		s,
		c.end.x,
		corridor.position.y,
		corridor.end.x,
		corridor.end.y,
		floor_h - SLAB,
		floor_h,
		MAT_OBSTACLE,
		MapKit.Kind.FLOOR
	)
	kit.wall_x(
		s,
		c.end.x,
		corridor.end.x,
		corridor.position.y - WALL / 2,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE,
		[[CELLAR_CAGES.x, CELLAR_CAGES.y, ceiling]]
	)
	kit.wall_x(
		s,
		c.position.x - WALL,
		corridor.end.x,
		corridor.end.y + WALL / 2,
		floor_h,
		ceiling,
		WALL,
		MAT_CONCRETE
	)
	var mid := (corridor.position.y + corridor.end.y) / 2.0
	for x: float in CELLAR_FIRE_DOORS:
		kit.wall_y(
			s,
			corridor.position.y - WALL,
			corridor.end.y + WALL,
			x,
			-CAR_PARK_DEPTH + DOOR_TOP,
			ceiling,
			WALL,
			MAT_CONCRETE
		)
		var leaf := corridor.size.y / 2.0
		_door(Vector3(x, floor_h, mid - leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
		_door(Vector3(x, floor_h, mid + leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
	# Cellar cages in an alcove north of the corridor: grilles, boxes inside,
	# the middle one left open.
	var cages := CELLAR_CAGES
	var back := corridor.position.y - CELLAR_CAGE_DEPTH
	var grille := _material("grille")
	kit.box(
		s,
		cages.x,
		back,
		cages.y,
		corridor.position.y,
		floor_h - SLAB,
		floor_h,
		MAT_OBSTACLE,
		MapKit.Kind.FLOOR
	)
	kit.wall_x(s, cages.x, cages.y, back - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	var cage := 3.0
	var count := roundi((cages.y - cages.x) / cage)
	for i in count + 1:
		var x := cages.x + i * cage
		kit.box(s, x - 0.03, back, x + 0.03, corridor.position.y, floor_h, ceiling, grille)
	for i in count:
		var x := cages.x + i * cage
		# Boxes at the back; in a prison cage, pushed west, out of the way.
		var junk := 0.2 if i in PRISON_CAGES else 0.4
		kit.box(
			s,
			x + junk,
			back + 0.1,
			x + junk + 0.8 + (0.2 if junk > 0.3 else 0.0),
			back + 0.7,
			floor_h,
			floor_h + 0.8,
			MAT_OBSTACLE,
			MapKit.Kind.FLOOR
		)
		if i in PRISON_CAGES:
			# A prison cage (S-018): its gate is the Cage entity.
			kit.box(
				s,
				x,
				corridor.position.y - 0.05,
				x + cage - PRISON_GATE_WIDTH,
				corridor.position.y,
				floor_h,
				ceiling,
				grille,
				MapKit.Kind.FLOOR
			)
			_cages.append(
				Vector3(x + cage - PRISON_GATE_WIDTH / 2.0, floor_h, corridor.position.y - 0.025)
			)
		elif i != count / 2:
			kit.box(
				s,
				x,
				corridor.position.y - 0.05,
				x + cage,
				corridor.position.y,
				floor_h,
				ceiling,
				grille,
				MapKit.Kind.FLOOR
			)
