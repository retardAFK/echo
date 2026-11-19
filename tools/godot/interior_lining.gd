extends "res://tools/godot/interior_lining_rooms.gd"
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
## Its constants, helpers and room decor live in the files it extends,
## see interior_lining_kit.gd.


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
	_hospital(kit)


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


## The hospital (S-014): its stairwells, then the rooms of each level by
## Hospital.ROOM_TILES (the order of WEST_ROOMS and EAST_ROOMS), the lift
## lobby, then the corridor.
func _hospital(kit: RefCounted) -> void:
	var r := Hospital.RECT
	var levels: Array = Hospital.LEVELS
	var top: float = levels[-1] + Hospital.STOREY
	var west := Vector2(r.position.x, Hospital.CORRIDOR.x)
	var east := Vector2(Hospital.CORRIDOR.y, r.end.x)
	for stairs: Rect2 in [
		_rect(east.x, r.position.y, east.y, Hospital.NORTH_STAIRS.end.y + 0.3),
		_rect(west.x, Hospital.SOUTH_STAIRS.position.y - 0.3, west.y, r.end.y),
	]:
		kit.zone(stairs, levels[0], top, Tile.STAIRS, Tile.TERRAZZO, Tile.CEILING)
	for h: float in levels:
		var tiles: Array = Hospital.ROOM_TILES[h]
		for side in 2:
			var span := west if side == 0 else east
			var rooms: Array = (Hospital.WEST_ROOMS if side == 0 else Hospital.EAST_ROOMS)[h]
			for i in rooms.size():
				var pair: Array = tiles[side][i]
				kit.zone(
					_rect(span.x, rooms[i][0], span.y, rooms[i][1]),
					h,
					h + Hospital.STOREY,
					Tile[pair[0]],
					Tile[pair[1]],
					Tile.CEILING
				)
		var floor_tile := Tile.CONCRETE if h < 0.0 else Tile.WARD_LINO
		var lobby := _rect(east.x, Hospital.LIFT.position.y - 0.2, east.y, 91.0)
		kit.zone(lobby, h, h + Hospital.STOREY, Tile.WARD_CORRIDOR, floor_tile, Tile.CEILING)
		var corridor := _rect(west.y, r.position.y, east.x, r.end.y)
		kit.zone(corridor, h, h + Hospital.STOREY, Tile.WARD_CORRIDOR, floor_tile, Tile.CEILING)


# --- Hospital decor ---


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
	_hospital_decor(node, lights)
