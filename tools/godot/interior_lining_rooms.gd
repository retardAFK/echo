extends "res://tools/godot/interior_lining_kit.gd"
## The decor of each kind of room of the interior lining (S-019, S-014,
## S-022 T-432): halls, corridors, stairwells, flats, cellars, great hall,
## offices, shops, car park, hospital. See interior_lining_kit.gd.


## The hospital (S-014, T-190): the corridor of each level cut in three
## stretches, each its own decor mesh, drawn near it only: its tubes along the
## ceiling, mostly dead, the live ones baked; one tube per room; papers; the
## exit signs. The tubes that stutter are NeonTube scenes (Hospital.NEONS),
## their place on the ceiling left to them.
func _hospital_decor(node: Node3D, lights: Node3D) -> void:
	var levels: Array = Hospital.LEVELS
	var x := (Hospital.CORRIDOR.x + Hospital.CORRIDOR.y) / 2.0
	var r := Hospital.RECT
	var stretch := r.size.y / HOSPITAL_STRETCHES
	for li in levels.size():
		var h: float = levels[li]
		var ceiling: float = h + Hospital.STOREY - _c("SLAB")
		for k in HOSPITAL_STRETCHES:
			var y0 := r.position.y + k * stretch
			var y1 := y0 + stretch
			_begin(_kit.world(x, (y0 + y1) / 2.0, h + 1.5))
			var y := y0 + HOSPITAL_TUBE_STEP / 2.0
			var first := true
			while y < y1:
				if not _is_neon(x, h, y):
					# One live tube at least in each stretch, the first.
					var alive := first or _rng.randf() < HOSPITAL_ALIVE
					first = false
					_tube_y(x, y, ceiling, alive)
					if alive:
						_light(lights, x, y, ceiling - 0.3, TUBE_COLOR, 1.1, 6.0)
				y += HOSPITAL_TUBE_STEP
			for side in 2:
				var rooms: Array = (Hospital.WEST_ROOMS if side == 0 else Hospital.EAST_ROOMS)[h]
				var cx := (r.position.x + Hospital.CORRIDOR.x) / 2.0
				if side == 1:
					cx = (Hospital.CORRIDOR.y + r.end.x) / 2.0
				for room: Array in rooms:
					var cy := (float(room[0]) + float(room[1])) / 2.0
					if cy < y0 or cy >= y1 or _is_neon(cx, h, cy):
						continue
					var alive := _rng.randf() < HOSPITAL_ALIVE
					_tube_y(cx, cy, ceiling, alive)
					if alive:
						_light(lights, cx, cy, ceiling - 0.3, TUBE_COLOR, 0.8, 5.0)
			var w: float = _c("WALL")
			_papers(Rect2(x - 1.2, y0, 2.4, stretch), h, 6)
			# Green exit signs over the stairwells' ends of the corridor.
			for end_y: float in [r.position.y + w, r.end.y - w]:
				if end_y >= y0 and end_y < y1:
					var dy := 0.03 if end_y < y1 - 1.0 else -0.03
					_box(x - 0.3, end_y, h + 2.3, x + 0.3, end_y + dy, h + 2.47, EXIT_COLOR, true)
			_commit(node, "Hospital%d_%d" % [li, k], HOSPITAL_DECOR_DISTANCE)


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
		# A puddle for the footsteps too (S-012, T-143).
		puddles.append(AABB(_kit.world(p.x - 0.8, p.y - 0.8, floor_h), Vector3(1.6, 0.01, 1.6)))
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
