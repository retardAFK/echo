extends "res://tools/godot/tilleuls_layout.gd"
## Shared state and small helpers of the cité's generator (spec S-006,
## S-022 T-432): materials, doors, windows, model placement, groups.
## See tilleuls_layout.gd for the chain of files.

var kit := MapKit.new()

var _root: Node3D

var _materials := {}

## Doors to place once the structures are built: plan position (x, h, y),
## yaw in degrees, width, kind (S-016).
var _doors: Array = []

var _metal_floors: Array[MetalFloor] = []

## Cages of the prison to place once the structures are built: the plan
## point (x, height, y) of the middle of each one's gate (S-018).
var _cages: Array[Vector3] = []


## A strip of asphalt between two plan points, a little wider than the path so
## the corners join.
func _path_segment(s: MapKit.Structure, a: Vector2, b: Vector2) -> void:
	var half := PATH_WIDTH / 2.0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half
	kit.box(s, lo.x, lo.y, hi.x, hi.y, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


## Two flights side by side from x0, the landing to the south on STAIR_LANDING_Y:
## up to the north on the west one, a mid landing, back south on the east one.
func _switchback(
	s: MapKit.Structure, x0: float, h: float, steps: Material, divider: Material
) -> void:
	var half := STOREY / 2.0
	var west_end := x0 + STAIR_FLIGHT_WIDTH
	var east_start := west_end + STAIR_DIVIDER
	var east := east_start + STAIR_FLIGHT_WIDTH
	var north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH
	kit.ramp(s, x0, STAIR_LANDING_Y, west_end, north, h, h + half, false, steps)
	kit.box(
		s,
		x0,
		north - STAIR_MID_LANDING,
		east,
		north,
		h + half - SLAB,
		h + half,
		steps,
		MapKit.Kind.FLOOR
	)
	kit.ramp(s, east_start, north, east, STAIR_LANDING_Y, h + half, h + STOREY, false, steps)
	kit.box(s, west_end, north, east_start, STAIR_LANDING_Y, h, h + STOREY, divider)


## Records a door to place once the structures are built (S-016): at a plan
## point (x, height, y), its leaf turned by yaw degrees (0: across X).
func _door(at: Vector3, yaw: float, width: float, kind := Door.Kind.NORMAL, bell := false) -> void:
	_doors.append([at, yaw, width, kind, bell])


## Whether a door stands between two rooms of a visited building: a meter
## each side of it is inside one (T-244).
func _is_inner_door(at: Vector3, yaw: float) -> bool:
	var across := Vector2(0, 1) if is_zero_approx(fmod(yaw, 180.0)) else Vector2(1, 0)
	for side: float in [-1.0, 1.0]:
		var point := Vector2(at.x, at.z) + across * side
		if not _in_building(point, at.y + 1.0):
			return false
	return true


## Whether a plan point at this height is inside a visited building.
func _in_building(point: Vector2, h: float) -> bool:
	var data := _buildings()
	var extras := _extra_boxes()
	for building_name: String in data:
		var entry: Array = data[building_name]
		var boxes: Array = [[entry[0], entry[1], entry[2]]] + extras.get(building_name, [])
		for box: Array in boxes:
			if (box[0] as Rect2).has_point(point) and h > box[1] and h < box[2]:
				return true
	return false


## Window openings of a storey at height h, one every WINDOW_STEP meters.
func _windows(from: float, to: float, h: float) -> Array:
	var gaps: Array = []
	var at := from + WINDOW_INSET
	while at + WINDOW_WIDTH <= to:
		gaps.append([at, at + WINDOW_WIDTH, h + WINDOW_TOP, h + WINDOW_SILL])
		at += WINDOW_STEP
	return gaps


## Two leaves meeting in the middle of a doorway this wide.
func _double_door(at: Vector3, yaw: float, width: float, kind := Door.Kind.NORMAL) -> void:
	var leaf := width / 2.0
	var along := Vector3(leaf / 2.0, 0, 0) if is_zero_approx(yaw) else Vector3(0, 0, leaf / 2.0)
	_door(at - along, yaw, leaf, kind)
	_door(at + along, yaw, leaf, kind)


## A metal floor over a plan rectangle, from the ground to a little above
## the height.
func _metal_floor(node_name: String, rect: Rect2, top: float) -> void:
	var floor_box := MetalFloor.new()
	floor_box.name = node_name
	floor_box.size = Vector3(rect.size.x, top + 2.0, rect.size.y)
	var c := rect.get_center()
	floor_box.position = kit.world(c.x, c.y, floor_box.size.y / 2.0 - 0.5)
	_metal_floors.append(floor_box)


## Scan volumes (Q6) with their lights, and the fuse slots (Q5).
## Each entry: plan rectangle, floor and top heights, lights, fuse slots.
func _buildings() -> Dictionary:
	var tower_top := TOWER_VISITED_STOREYS * STOREY
	var data := {
		"Tower":
		[
			TOWER,
			0.0,
			tower_top,
			[
				[Vector3(104, 2.6, 92), 6.0],
				[Vector3(96, 8.6, 100), 6.0],
				[Vector3(112, 14.6, 100), 6.0]
			],
			[
				Vector3(113, 0, 89),
				Vector3(113, 6, 110.5),
				Vector3(96, 9, 109),
				Vector3(113, 12, 108),
				Vector3(113, 3, 110.5),
				Vector3(94, 6, 102.5)
			]
		],
		"SocialCentre":
		[
			SOCIAL_CENTRE,
			0.0,
			SOCIAL_CENTRE_HEIGHT,
			[[Vector3(151, 3.4, 72), 9.0], [Vector3(161.5, 3.4, 72), 5.0]],
			[
				Vector3(142, 0, 62),
				Vector3(176, 0, 62),
				Vector3(176, 0, 74),
				Vector3(170, 0, 82),
				Vector3(158.5, 0, 79),  # Off the kitchen island (S-020, T-341).
				Vector3(170, 0, 70.5)
			]
		],
		"Gallery":
		[
			GALLERY,
			0.0,
			GALLERY_HEIGHT,
			[[Vector3(58, 2.9, 143), 5.0], [Vector3(66, 2.8, 137), 6.0]],
			[
				Vector3(55, 0, 143),
				Vector3(61, 0, 145),
				Vector3(77.5, 0, 139.6),  # Off the gondolas (S-020, T-341).
				Vector3(84, 0, 148),
				Vector3(47.5, 0, 148),
				Vector3(71, 0, 146)
			]
		],
		"CarPark":
		[
			CAR_PARK,
			-CAR_PARK_DEPTH,
			0.0,
			[[Vector3(152, -0.6, 106), 7.0], [Vector3(170, -0.6, 106), 7.0]],
			[
				Vector3(142, -3, 97),
				Vector3(178, -3, 97),
				Vector3(142, -3, 115),
				Vector3(166, -3, 115),
				Vector3(178.5, -3, 111),
				Vector3(110, -3, 97.2)
			]
		],
		"Garages": [GARAGES, 0.0, GARAGE_HEIGHT, [], []],
	}
	# Spec S-014: one volume per level of the hospital.
	for level: Array in Hospital.scan_levels():
		data[level[0]] = level[2]
	return data


## Parts of a building outside its main box (S-016, Q5): plan rectangle,
## floor and top heights. The cellar stairs belong to the tower; the cellar
## corridor, past them, to the car park, up to its ceiling: not the street
## above it.
func _extra_boxes() -> Dictionary:
	var c := CELLAR_STAIRS
	var corridor := CELLAR_CORRIDOR
	var cages := Rect2(
		CELLAR_CAGES.x,
		corridor.position.y - CELLAR_CAGE_DEPTH,
		CELLAR_CAGES.y - CELLAR_CAGES.x,
		CELLAR_CAGE_DEPTH
	)
	var under := Rect2(c.end.x, corridor.position.y, corridor.end.x - c.end.x, corridor.size.y)
	var boxes := {
		"Tower": [[c, -CAR_PARK_DEPTH, 0.0]],
		"CarPark":
		[[under, -CAR_PARK_DEPTH, -GROUND_THICKNESS], [cages, -CAR_PARK_DEPTH, -GROUND_THICKNESS]],
	}
	boxes.merge(Hospital.extra_boxes())
	return boxes


## Puts a wall object (origin on the floor, front toward +Z) on the nearest
## wall around a point, facing away from it.
func _snap_to_wall(node: Node3D, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.3
	var best := at
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
	if best_distance >= FUSE_BOX_WALL_SEARCH:
		push_warning("No wall near %s" % node.name)
	node.global_position = Vector3(best.x, at.y, best.z) + facing * 0.01
	node.global_rotation.y = atan2(facing.x, facing.z)


## A hiding spot with its back against the nearest wall, its front (+Z) toward
## the room.
func _place_spot(parent: Node3D, scene: PackedScene, node_name: String, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var spot: Node3D = scene.instantiate()
	spot.name = node_name
	parent.add_child(spot)
	spot.owner = _root
	spot.position = kit.world(at.x, at.z, at.y)
	var from := spot.position + Vector3.UP * SPOT_RAY_HEIGHT
	var best_distance := SPOT_WALL_SEARCH
	var wall := from
	var front := Vector3.BACK
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(
			from, from + direction * SPOT_WALL_SEARCH, MapKit.WALLS_LAYER
		)
		if spot.has_node("Body"):
			query.exclude = [spot.get_node("Body").get_rid()]
		var hit := space.intersect_ray(query)
		if hit and from.distance_to(hit.position) < best_distance:
			best_distance = from.distance_to(hit.position)
			wall = hit.position
			front = -direction
	if best_distance >= SPOT_WALL_SEARCH:
		push_warning("No wall near %s" % node_name)
		return
	var depth := 0.0
	if spot.has_node("Body"):
		var shape: BoxShape3D = spot.get_node("Body/CollisionShape3D").shape
		depth = shape.size.z
	var center := wall + front * (depth / 2.0 + 0.02)
	spot.position = Vector3(center.x, at.y, center.z)
	spot.rotation.y = atan2(front.x, front.z)


## A pickup on whatever lies below its point.
func _place_pickup(parent: Node3D, scene: PackedScene, node_name: String, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var node: Node3D = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	var from := kit.world(at.x, at.z, at.y + 1.5)
	var hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5)
	)
	node.position = hit.position if hit else kit.world(at.x, at.z, at.y)
	node.rotation.y = fposmod(at.x * 1.3 + at.z * 0.7, TAU)  # Not all lined up.


## The ground plan rectangle a piece of furniture covers, and its height in
## the third value of the model's box.
func _footprint(piece: Array) -> Rect2:
	var box := _model_box(FURNITURE_MODELS[piece[0]])
	var at: Vector3 = piece[1]
	var facing: Vector2 = piece[2]
	var side := Vector2(facing.y, -facing.x)  # The model's +X on the plan (_place_model).
	var lo := Vector2(INF, INF)
	var hi := -lo
	for x: float in [box.position.x * piece[3], box.end.x * piece[3]]:
		for z: float in [box.position.z, box.end.z]:
			var corner := Vector2(at.x, at.z) + side * x + facing * z
			lo = lo.min(corner)
			hi = hi.max(corner)
	return Rect2(lo, hi - lo)


## The box around a model's meshes, in its own space.
func _model_box(scene: PackedScene) -> AABB:
	var model: Node3D = scene.instantiate()
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := mesh.transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	model.free()
	return box


func _sound(
	parent: Node3D, node_name: String, stream: AudioStream, at: Vector2, h: float
) -> AudioStreamPlayer3D:
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
func _place_model(
	parent: Node3D,
	scene: PackedScene,
	node_name: String,
	at: Vector2,
	normal: Vector2,
	scale := Vector3.ONE,
	h := 0.0
) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.name = node_name
	var z_axis := Vector3(normal.x, 0, normal.y)
	var x_axis := Vector3.UP.cross(z_axis)
	model.transform = Transform3D(
		Basis(x_axis * scale.x, Vector3.UP * scale.y, z_axis * scale.z), kit.world(at.x, at.y, h)
	)
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
	dressing: FacadeDressing,
	rng: RandomNumberGenerator,
	wall: int,
	side: Array,
	storeys: int,
	porch: Variant,
	tower := false
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
		var under_porch: bool = (
			porch != null and mid.x > porch.x and mid.x < porch.y and absf(normal.y) > 0.5
		)
		var balconies := rng.randf() < BALCONY_SHARE
		# The hall entrances of the tower stay open (north and south, ground floor).
		var entrance: bool = (
			tower
			and absf(normal.y) > 0.5
			and (
				mid.x > TOWER_NORTH_DOORS.x - 3.0 and mid.x < TOWER_NORTH_DOORS.y + 1.0
				if normal.y < 0
				else mid.x > TOWER_SOUTH_DOORS.x - 2.0 and mid.x < TOWER_SOUTH_DOORS.y + 2.0
			)
		)
		var fire_escape: bool = (
			tower
			and normal.x > 0.5
			and absf(mid.y - (FIRE_ESCAPE_DOOR.x + FIRE_ESCAPE_DOOR.y) / 2.0) < width
		)
		for storey in storeys:
			if under_porch and storey * STOREY < PORCH_HEIGHT:
				continue
			if entrance and storey == 0:
				continue
			# The doors onto the fire escape stay clear (S-016).
			if fire_escape and storey > 0 and storey < TOWER_VISITED_STOREYS:
				continue
			var module: int
			if tower and storey > 0 and storey < TOWER_VISITED_STOREYS:
				module = Module.OPEN
			elif storey == 0 and tower and _opens_vault(mid):
				module = Module.OPEN  # The hall's broken window (S-020, T-340).
				rng.randf()  # The same draws as before, the cité keeps its look.
			elif storey == 0:
				var door := (
					not tower and column % door_every == door_every / 2 and absf(normal.y) > 0.5
				)
				module = (
					Module.DOOR
					if door
					else (Module.WALLED if rng.randf() < WALLED_SHARE else Module.PLAIN)
				)
			elif balconies:
				module = Module.BALCONY
			else:
				module = Module.LIT if rng.randf() < LIT_SHARE else Module.PLAIN
			var origin := kit.world(at.x, at.y) + Vector3.UP * (storey * STOREY)
			dressing.panels.append(Transform3D(basis, origin))
			dressing.variants.append(module)
			dressing.walls.append(wall)


## Whether a ground-floor module of the tower, centered on mid, is the one
## in front of the hall's broken window (S-020, T-340).
func _opens_vault(mid: Vector2) -> bool:
	var window := TOWER_VAULT_WINDOW
	return absf(mid.x - TOWER.position.x) < 0.1 and mid.y > window.x and mid.y < window.y


## Instances a prop at a plan point, its local -Z (front) turned toward facing.
func _place(
	parent: Node3D, scene: PackedScene, node_name: String, at: Vector2, facing: Vector2
) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	node.position = kit.world(at.x, at.y)
	node.rotation.y = atan2(-facing.x, -facing.y)
	return node


func _add_light(
	parent: Node3D,
	node_name: String,
	at: Vector2,
	height: float,
	color: Color,
	energy: float,
	light_range: float,
	fade := true
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
