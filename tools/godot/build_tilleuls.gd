extends "res://tools/godot/tilleuls_places.gd"
## Generates the cité des Tilleuls (spec S-006) from its validated paper plan
## (specs/S-006-cite-des-tilleuls/plan-map.svg): ground, borders, blocks of flats,
## visitable buildings, landmarks, gameplay points, then bakes the navigation mesh.
## Run after any change, then commit the scene and the navigation mesh:
##   godot --headless tools/godot/build_tilleuls.tscn
## (a scene rather than -s, so the autoloads the game scripts use are loaded).
## The map is only edited here: a hand edit of the scene is lost on the next run.
## Coordinates are plan coordinates (see map_kit.gd): x east, y south, meters.
## Its layout and builders live in the files it extends, see tilleuls_layout.gd.


func _ready() -> void:
	kit.origin = Vector2(MAP_SIZE, MAP_SIZE) / 2.0
	_root = Node3D.new()
	_root.name = "Tilleuls"
	_build_ground()
	_build_borders()
	_build_facades()
	_build_landmarks()
	_build_tower()
	_build_social_centre()
	_build_gallery()
	_build_car_park()
	_build_cellars()
	Hospital.new(self).build()  # Spec S-014, in place of block C.
	_build_garages()
	_build_furniture()
	var lining := InteriorLining.new(self)
	lining.add_zones(kit)
	kit.build(_root)
	_add_doors()
	_add_buildings()
	Hospital.new(self).add_gameplay()  # Monitors and ventilation (S-014, T-186).
	_add_props()
	_add_navigation()
	_add_facade_dressing()
	_add_gallery_dressing()
	_add_social_centre_dressing()
	_add_car_park_dressing()
	_add_outdoor_dressing()
	_add_furniture()
	lining.dress(_root)
	var floors := FloorBuilder.new(self, kit)
	floors.add_puddles(_root, _root)  # Spec S-012, T-143.
	_add_ambience()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bake_light()
	_place_fuse_boxes()
	_place_objectives()
	_hang_cameras()
	_hang_speakers()
	_place_ruses()
	var region: NavigationRegion3D = _root.get_node("NavigationRegion3D")
	var started := Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	var error := ResourceSaver.save(mesh, NAVMESH_PATH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(NAVMESH_PATH)
	print(
		(
			"Baked %d polygons in %d ms, save error %d"
			% [mesh.get_polygon_count(), Time.get_ticks_msec() - started, error]
		)
	)
	_root.get_parent().remove_child(_root)
	_add_gameplay()
	var surfaces := FloorSurfaces.new()
	surfaces.name = "FloorSurfaces"
	surfaces.surfaces = floors.save_surfaces(lining.puddles)
	_add(surfaces)
	var packed := PackedScene.new()
	error = packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE_PATH, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s, error %d" % [SCENE_PATH, error])
	_root.free()
	get_tree().quit(error)


# --- Ground and borders -----------------------------------------------------


## The doors and the metal floors. Doors are not navigation sources: the
## navigation mesh goes through their doorways, except for the emergency
## exits, which the AIs could not open from outside.
func _add_doors() -> void:
	var doors := _group("Doors")
	var exits := Node3D.new()
	exits.name = "EmergencyExits"
	exits.add_to_group("navigation_source", true)
	doors.add_child(exits)
	exits.owner = _root
	var count := 0
	for entry: Array in _doors:
		var door: Door = DOOR.instantiate()
		count += 1
		door.name = "Door%d" % count
		var at: Vector3 = entry[0]
		door.position = kit.world(at.x, at.z, at.y)
		door.rotation_degrees.y = entry[1]
		door.width = entry[2]
		door.kind = entry[3]
		door.bell = entry[4]
		door.indoor = _is_inner_door(at, entry[1])
		var parent := exits if door.kind == Door.Kind.EMERGENCY else doors
		parent.add_child(door)
		door.owner = _root
	_add_prison()
	_add_network()
	var metal := _group("MetalFloors")
	for floor_box in _metal_floors:
		metal.add_child(floor_box)
		floor_box.owner = _root


## The network of the cité (S-018): its terminals (their desks are navigation
## sources), its cameras, loudspeakers and metal shutters (not navigation
## sources: the mesh goes under a shutter, the AIs see it down on their way).
func _add_network() -> void:
	var network := Node.new()
	network.name = "Network"
	network.set_script(NETWORK_SCRIPT)
	_add(network)
	var desks := Node3D.new()
	desks.name = "Terminals"
	desks.add_to_group("navigation_source", true)
	network.add_child(desks)
	desks.owner = _root
	var terminals_list: Array = TERMINALS + Hospital.TERMINALS  # S-014.
	for i in terminals_list.size():
		var entry: Array = terminals_list[i]
		var scene: PackedScene = TERMINAL_KEYPAD if entry[2] == Terminal.Kind.CODE else TERMINAL
		var terminal: Terminal = scene.instantiate()
		terminal.name = "Terminal%d" % (i + 1)
		var at: Vector3 = entry[0]
		terminal.position = kit.world(at.x, at.z, at.y)
		terminal.rotation_degrees.y = entry[1]
		terminal.kind = entry[2]
		terminal.label_key = entry[3]
		desks.add_child(terminal)
		terminal.owner = _root
	var cameras := Node3D.new()
	cameras.name = "Cameras"
	network.add_child(cameras)
	cameras.owner = _root
	var cameras_list: Array = CAMERAS + Hospital.CAMERAS  # S-014.
	for i in cameras_list.size():
		var entry: Array = cameras_list[i]
		var camera: SecurityCamera = SECURITY_CAMERA.instantiate()
		camera.name = "Camera%d" % (i + 1)
		var at: Vector3 = entry[0]
		var target: Vector3 = entry[1]
		var from := kit.world(at.x, at.z, at.y)
		var to := kit.world(target.x, target.z, target.y)
		camera.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
		camera.label_key = entry[2]
		cameras.add_child(camera)
		camera.owner = _root
	var speakers := Node3D.new()
	speakers.name = "Loudspeakers"
	network.add_child(speakers)
	speakers.owner = _root
	var speakers_list: Array = SPEAKERS + Hospital.SPEAKERS  # S-014.
	for i in speakers_list.size():
		var entry: Array = speakers_list[i]
		var speaker: Node3D = LOUDSPEAKER.instantiate()
		speaker.name = "Loudspeaker%d" % (i + 1)
		var at: Vector3 = entry[0]
		speaker.position = kit.world(at.x, at.z, at.y)
		speaker.rotation_degrees.y = entry[1]
		speaker.set("label_key", entry[2])
		speakers.add_child(speaker)
		speaker.owner = _root
	var shutters := Node3D.new()
	shutters.name = "Shutters"
	network.add_child(shutters)
	shutters.owner = _root
	for i in SHUTTERS.size():
		var entry: Array = SHUTTERS[i]
		var shutter: Node3D = REMOTE_SHUTTER.instantiate()
		shutter.name = "Shutter%d" % (i + 1)
		var at: Vector3 = entry[0]
		shutter.position = kit.world(at.x, at.z, at.y)
		shutter.rotation_degrees.y = entry[1]
		shutter.set("width", entry[2])
		shutter.set("height", entry[3])
		shutter.set("label_key", entry[4])
		shutters.add_child(shutter)
		shutter.owner = _root


## The prison (S-018, Q1): a Cage in each prison cage's grille. Not a
## navigation source: the mesh goes into the cages through their gates.
func _add_prison() -> void:
	var prison := Node3D.new()
	prison.name = "Prison"
	prison.set_script(PRISON_SCRIPT)
	prison.set("settings", PRISON_SETTINGS)
	_add(prison)
	for i in _cages.size():
		var cage: Node3D = CAGE.instantiate()
		cage.name = "Cage%d" % (i + 1)
		var at := _cages[i]
		cage.position = kit.world(at.x, at.z, at.y)
		prison.add_child(cage)
		cage.owner = _root


func _add_buildings() -> void:
	var parent := Node3D.new()
	parent.name = "Buildings"
	_add(parent)
	var slots_parent := Node3D.new()
	slots_parent.name = "FuseSlots"
	_add(slots_parent)
	var data := _buildings()
	for building_name: String in data:
		var entry: Array = data[building_name]
		var rect: Rect2 = entry[0]
		var bottom: float = entry[1]
		var top: float = entry[2]
		var building: Node3D = BUILDING.instantiate()
		building.name = building_name
		var center := rect.get_center()
		building.position = kit.world(center.x, center.y, (bottom + top) / 2.0)
		building.set("size", Vector3(rect.size.x, top - bottom, rect.size.y))
		building.set("display_key", "BUILDING_" + building_name.to_snake_case().to_upper())
		var level := Hospital.LEVEL_NAMES.find(building_name)
		if level >= 0:
			building.set("display_key", Hospital.LEVEL_KEYS[level])
			building.set("complex", Hospital.COMPLEX)
		var extras: Array[AABB] = []
		for extra: Array in _extra_boxes().get(building_name, []):
			var r2: Rect2 = extra[0]
			var lo := kit.world(r2.position.x, r2.position.y, extra[1]) - building.position
			extras.append(AABB(lo, Vector3(r2.size.x, extra[2] - extra[1], r2.size.y)))
		building.set("extra_boxes", extras)
		parent.add_child(building)
		building.owner = _root
		for i in entry[3].size():
			var spot: Vector3 = entry[3][i][0]
			var light := OmniLight3D.new()
			light.name = "Light%d" % (i + 1)
			light.light_color = Color(1, 0.96, 0.88)
			light.omni_range = entry[3][i][1]
			building.add_child(light)
			light.owner = _root
			light.position = kit.world(spot.x, spot.z, spot.y) - building.position
		if entry[4].is_empty():
			continue
		var slots := Node3D.new()
		slots.name = Hospital.COMPLEX if level >= 0 else building_name
		slots_parent.add_child(slots)
		slots.owner = _root
		for i in entry[4].size():
			var at: Vector3 = entry[4][i]
			var marker := Marker3D.new()
			marker.name = "Slot%d" % (i + 1)
			marker.position = kit.world(at.x, at.z, at.y)
			marker.add_to_group("fuse_slot", true)
			slots.add_child(marker)
			marker.owner = _root


## The transformer, the grille of the exit and the far end of the tunnel (S-007).
func _add_loop() -> void:
	var transformer := TRANSFORMER_NODE.instantiate()
	transformer.position = kit.world(100.5, 153.5)
	_add(_named(transformer, "TransformerPanel"))
	var gate := AnimatableBody3D.new()
	gate.set_script(EXIT_GATE_SCRIPT)
	gate.set("settings", LOOP_SETTINGS)
	gate.set("rise", EXIT_GATE_HEIGHT)
	var center := EXIT_GATE.get_center()
	gate.position = kit.world(center.x, center.y)
	_add(_named(gate, "ExitGate"))
	var size := Vector3(EXIT_GATE.size.x, EXIT_GATE_HEIGHT, EXIT_GATE.size.y)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	box.material = _material("grille")
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	gate.add_child(mesh)
	mesh.owner = _root
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position.y = size.y / 2.0
	gate.add_child(shape)
	shape.owner = _root
	var zone := Area3D.new()
	zone.set_script(EXIT_ZONE_SCRIPT)
	center = EXIT_ZONE.get_center()
	zone.position = kit.world(center.x, center.y, 2.0)
	_add(_named(zone, "ExitZone"))
	var zone_shape := CollisionShape3D.new()
	zone_shape.name = "CollisionShape3D"
	zone_shape.shape = BoxShape3D.new()
	zone_shape.shape.size = Vector3(EXIT_ZONE.size.x, 4.0, EXIT_ZONE.size.y)
	zone.add_child(zone_shape)
	zone_shape.owner = _root


## A fuse box on the nearest wall of each fuse slot (S-007, Q1). The slot
## marker stays in front of it: it is where the AI prey stands to use the box.
func _place_fuse_boxes() -> void:
	var space := _root.get_world_3d().direct_space_state
	for marker: Node3D in _root.get_node("FuseSlots").find_children("Slot*", "Marker3D"):
		var from := marker.global_position + Vector3.UP * 1.3
		var best: Vector3
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
		var box: Node3D = FUSE_BOX.instantiate()
		box.name = "FuseBox"
		box.set("building_name", String(marker.get_parent().name))
		marker.add_child(box)
		box.owner = _root
		if best_distance < FUSE_BOX_WALL_SEARCH:
			box.global_position = Vector3(best.x, marker.global_position.y, best.z) + facing * 0.01
		else:
			push_warning("No wall near %s" % marker.get_path())
		box.global_rotation.y = atan2(facing.x, facing.z)


## The relay switches and the post-its of the code (S-018, T-266): each
## switch on the nearest wall of its place, a post-it on the wall behind
## each terminal's desk (not the keypad's).
func _place_objectives() -> void:
	var relays := _group("Relays")
	var relays_list: Array = RELAYS + Hospital.RELAYS  # S-014.
	for i in relays_list.size():
		var entry: Array = relays_list[i]
		var at: Vector3 = entry[0]
		var marker := kit.world(at.x, at.z, at.y)
		var switch: Node3D = RELAY_SWITCH.instantiate()
		switch.name = "Relay%d" % (i + 1)
		switch.set("building_name", entry[1])
		relays.add_child(switch)
		switch.owner = _root
		_snap_to_wall(switch, marker)
	var spots := _group("CodeSpots")
	var count := 0
	for terminal: Terminal in _root.get_node("Network/Terminals").get_children():
		if terminal.kind == Terminal.Kind.CODE:
			_snap_to_wall(terminal, terminal.global_position)  # The keypad's box (T-316).
			continue
		count += 1
		var spot: Node3D = CODE_SPOT.instantiate()
		spot.name = "CodeSpot%d" % count
		spots.add_child(spot)
		spot.owner = _root
		var from := terminal.to_global(Vector3(0.4, 1.4, 0.0))
		var back := -terminal.global_basis.z
		var hit := _root.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + back * 2.0, MapKit.WALLS_LAYER)
		)
		if hit:
			spot.global_position = hit.position - back * 0.01
		else:
			push_warning("No wall behind %s" % terminal.name)
			spot.global_position = from + back * 0.58
		spot.global_rotation.y = terminal.global_rotation.y


## Each camera on the nearest wall around its plan point, at the same height,
## still looking at what it watches (S-020, T-315, piste N1): none hangs in
## mid air any more. Prints how far each one moved.
func _hang_cameras() -> void:
	var space := _root.get_world_3d().direct_space_state
	for camera: SecurityCamera in _root.get_node("Network/Cameras").get_children():
		var from := camera.global_position
		var target := from + -camera.global_basis.z * 15.0
		var best_distance := CAMERA_WALL_SEARCH
		var best: Dictionary = {}
		for i in 16:
			var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
			var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(
					from, from + direction * CAMERA_WALL_SEARCH, MapKit.WALLS_LAYER
				)
			)
			if hit and from.distance_to(hit.position) < best_distance:
				best_distance = from.distance_to(hit.position)
				best = hit
		if best.is_empty():
			_add_camera_mast(camera, target)
			continue
		if best_distance < CAMERA_ON_WALL:
			continue  # Already against its wall.
		var normal: Vector3 = best.normal
		normal.y = 0.0
		normal = normal.normalized()
		var spot: Vector3 = best.position + normal * CAMERA_WALL_GAP
		spot.y = from.y
		if (target - spot).normalized().dot(normal) < -0.1:
			target = spot + normal * 10.0 + Vector3.DOWN * 3.0  # Not into the wall.
		camera.global_transform = Transform3D(Basis.looking_at(target - spot, Vector3.UP), spot)
		print("%s: %.1f m to its wall" % [camera.name, best_distance])


## Puts each loudspeaker against the wall behind it (S-020, T-325): two hung
## more than a meter from their wall (the social centre's stage, the tower).
func _hang_speakers() -> void:
	var space := _root.get_world_3d().direct_space_state
	for speaker: Node3D in _root.get_node("Network/Loudspeakers").get_children():
		if PlacementCheck.gap(speaker) <= PlacementCheck.MAX_GAP / 2.0:
			continue  # Already against a wall.
		var from := speaker.global_position
		var back := speaker.global_basis.z
		back.y = 0.0
		var hit := _wall_hit(space, from, back.normalized(), SPEAKER_WALL_SEARCH)
		if not hit:
			push_warning("No wall behind %s" % speaker.name)  # PlacementCheck says where.
			continue
		var gap := from.distance_to(hit.position)
		if gap <= SPEAKER_WALL_GAP + 0.02:
			continue  # Already against its wall.
		var normal: Vector3 = hit.normal
		normal.y = 0.0
		normal = normal.normalized()
		var spot: Vector3 = hit.position + normal * SPEAKER_WALL_GAP
		spot.y = from.y
		speaker.global_position = spot
		speaker.global_rotation.y = atan2(-normal.x, -normal.z)  # Its front (-Z) off the wall.
		print("%s: %.1f m to its wall" % [speaker.name, gap])


## The first wall a flat ray meets, or an empty dictionary.
func _wall_hit(
	space: PhysicsDirectSpaceState3D, from: Vector3, direction: Vector3, reach: float
) -> Dictionary:
	return space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + direction * reach, MapKit.WALLS_LAYER)
	)


## A grey mast from the ground up to a camera far from any wall, the camera
## on its side toward what it watches.
func _add_camera_mast(camera: SecurityCamera, target: Vector3) -> void:
	var at := camera.global_position
	var ahead := Vector3(target.x - at.x, 0.0, target.z - at.z).normalized()
	var foot := Vector3(at.x, 0.0, at.z) - ahead * CAMERA_WALL_GAP
	var hit := _root.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(foot + Vector3.UP * at.y, foot + Vector3.DOWN * 10.0, 1)
	)
	if hit:
		foot.y = hit.position.y
	var height := at.y - foot.y + 0.15
	var mast := StaticBody3D.new()
	mast.name = camera.name + "Mast"
	camera.get_parent().add_child(mast)
	mast.owner = _root
	mast.global_position = foot + Vector3.UP * height / 2.0
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = CAMERA_MAST_RADIUS
	cylinder.bottom_radius = CAMERA_MAST_RADIUS
	cylinder.height = height
	cylinder.radial_segments = 6
	cylinder.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.33, 0.33)
	material.roughness = 0.9
	cylinder.material = material
	mesh.mesh = cylinder
	mast.add_child(mesh)
	mesh.owner = _root
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var body := CylinderShape3D.new()
	body.radius = CAMERA_MAST_RADIUS
	body.height = height
	shape.shape = body
	mast.add_child(shape)
	shape.owner = _root
	print("%s: on a mast of %.1f m" % [camera.name, height])


## The hiding spots, obstacles for the navigation mesh, and the pickups (S-008).
func _place_ruses() -> void:
	var spots := _group("Hideouts")
	spots.add_to_group("navigation_source", true)
	for i in CLOSETS.size():
		_place_spot(spots, CLOSET, "Closet%d" % (i + 1), CLOSETS[i])
	for i in DUMPSTERS.size():
		_place_spot(spots, DUMPSTER, "Dumpster%d" % (i + 1), DUMPSTERS[i])
	var families := {"Low": LOW_SPOT, "Makeshift": MAKESHIFT_SPOT, "Metal": METAL_SPOT}
	var counts := {}
	for entry: Array in FAMILY_SPOTS + Hospital.SPOTS:
		counts[entry[0]] = counts.get(entry[0], 0) + 1
		var node_name := "%s%d" % [entry[0], counts[entry[0]]]
		if entry.size() > 2:
			var spot: Node3D = families[entry[0]].instantiate()
			spot.name = node_name
			spots.add_child(spot)
			spot.owner = _root
			var at: Vector3 = entry[1]
			var front: Vector2 = entry[2]
			spot.position = kit.world(at.x, at.z, at.y)
			spot.rotation.y = atan2(front.x, front.y)
		else:
			_place_spot(spots, families[entry[0]], node_name, entry[1])
	var pickups := _group("Pickups")
	for kind: Array in [["Bottles", BOTTLE, "Bottle", BOTTLES], ["Decoys", DECOY, "Decoy", DECOYS]]:
		var parent := Node3D.new()
		parent.name = kind[0]
		pickups.add_child(parent)
		parent.owner = _root
		for i in kind[3].size():
			_place_pickup(parent, kind[1], "%s%d" % [kind[2], i + 1], kind[3][i])


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
	var cars := Node3D.new()
	cars.name = "CarAlarms"
	_add(cars)
	cars.add_to_group("navigation_source", true)
	for i in CAR_ALARMS.size():
		var scene := AMBULANCE_ALARM if i == AMBULANCE_CAR else CAR_ALARM
		_place(cars, scene, "Car%d" % (i + 1), CAR_ALARMS[i][0], CAR_ALARMS[i][1])
	_add_light(
		props,
		"TowerBeacon",
		Vector2(104, 100),
		TOWER_STOREYS * STOREY + 1.0,
		Color(1, 0.15, 0.1),
		2.0,
		6.0,
		false
	)
	_add_light(props, "SocialCentreLamp", Vector2(161.5, 58.5), 3.0, Color(1, 0.9, 0.7), 1.0, 5.0)
	_add_light(props, "LaundretteSign", Vector2(57.6, 137.5), 2.6, Color(0.7, 0.85, 1.0), 0.9, 5.0)
	_add_light(props, "CarParkSign", Vector2(127, 98.5), 3.0, Color(0.95, 0.95, 1.0), 0.8, 4.0)
	_add_light(
		props, "TransformerLight", Vector2(100.5, 158.5), 2.4, Color(0.35, 1, 0.55), 0.8, 5.0
	)


# --- Facade dressing (T-045) ------------------------------------------------


## Lays the facade modules on the blocks of flats and on the upper mass of the
## tower. The visited storeys of the tower keep their real windows.
func _add_facade_dressing() -> void:
	var dressing: FacadeDressing = FACADE_DRESSING.new()
	dressing.name = "FacadeDressing"
	dressing.models.assign(FACADE_MODELS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971  # Fixed: the cité looks the same after every generation.
	var wall := 0
	for facade_name: String in FACADES:
		var rect: Rect2 = FACADES[facade_name][0]
		var storeys: int = FACADES[facade_name][1]
		var porch: Variant = FACADES[facade_name][2]
		for side in _sides(rect):
			_dress_wall(dressing, rng, wall, side, storeys, porch)
			wall += 1
	for side in _sides(TOWER):
		_dress_wall(dressing, rng, wall, side, TOWER_STOREYS, null, true)
		wall += 1
	_add(dressing)


## Shop fronts, the laundrette and its machines (T-046). The models only
## dress the greybox walls, which keep the collisions.
func _add_gallery_dressing() -> void:
	var node := _group("GalleryDressing")
	var r := GALLERY
	var width := r.size.x / GALLERY_SHOPS
	var front := r.position.y + GALLERY_ARCADE_DEPTH - WALL / 2 - FACADE_OFFSET
	# The pharmacy, the tobacconist and the baker open since S-016 (T-240).
	var scenes := {
		0: SHOP_PHARMACIE, 1: LAUNDRETTE, 2: SHOP_TABAC, 3: SHOP_HALF, 4: SHOP_BOULANGERIE
	}
	for i: int in scenes:
		var east := r.position.x + (i + 1) * width
		_place_model(node, scenes[i], "Shop%d" % (i + 1), Vector2(east, front), Vector2.UP)
	var laundrette := r.position.x + width
	var back := r.end.y - GALLERY_BACK_CORRIDOR
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		_place_model(
			node, WASHERS, "Washers%d" % (i + 1), Vector2(mx + 0.61, back - 1.0), Vector2.UP
		)


## Window frames, the entrance canopy and its sign, the tables (T-046).
func _add_social_centre_dressing() -> void:
	var node := _group("SocialCentreDressing")
	var r := SOCIAL_CENTRE
	var n := 0
	for x: float in [146.0, 152.0, 168.0, 174.0]:  # North wall, seen from the north.
		n += 1
		_place_model(
			node,
			CENTRE_WINDOW,
			"Window%d" % n,
			Vector2(x, r.position.y - FACADE_OFFSET),
			Vector2.UP
		)
	for x: float in [144.0, 152.0, 168.0]:  # South wall.
		n += 1
		_place_model(
			node, CENTRE_WINDOW, "Window%d" % n, Vector2(x, r.end.y + FACADE_OFFSET), Vector2.DOWN
		)
	for y: float in [65.5, 73.5, 81.5]:  # East wall: narrower windows.
		n += 1
		var narrow := Vector3(1.5 / CENTRE_WINDOW_WIDTH, 1, 1)
		_place_model(
			node,
			CENTRE_WINDOW,
			"Window%d" % n,
			Vector2(r.end.x + FACADE_OFFSET, y),
			Vector2.RIGHT,
			narrow
		)
	_place_model(
		node, CENTRE_ENTRANCE, "Entrance", Vector2(162.6, r.position.y - FACADE_OFFSET), Vector2.UP
	)
	var tables: Array = [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]
	for i in tables.size():
		_place_model(node, FOLDING_TABLE, "Table%d" % (i + 1), tables[i], Vector2.UP)
	for i in 3:  # Office desks, smaller.
		_place_model(
			node,
			FOLDING_TABLE,
			"Desk%d" % (i + 1),
			Vector2(172, 64 + 8 * i),
			Vector2.UP,
			Vector3(0.8, 1, 0.8)
		)


## Every piece of furniture once (S-016, T-241): [model, plan point (x, height,
## y), facing, width scale], those of the flats on each visited storey, less
## those that would stand on a hiding spot, a pickup, a fuse slot or a point of
## the AIs.
func _furniture_pieces() -> Array:
	var pieces: Array = []
	for level in range(1, TOWER_VISITED_STOREYS):
		for piece: Array in FLAT_FURNITURE:
			var at: Vector2 = piece[1]
			pieces.append([piece[0], Vector3(at.x, level * STOREY, at.y), piece[2], 1.0])
	for piece: Array in FURNITURE + Hospital.FURNITURE:
		pieces.append([piece[0], piece[1], piece[2], piece[3] if piece.size() > 3 else 1.0])
	var keep_clear: Array = CLOSETS + BOTTLES + DECOYS + HIDING_SPOTS + PREY_ROUTE + PATROL_ROUTE
	for spot: Array in FAMILY_SPOTS + Hospital.SPOTS:
		keep_clear.append(spot[1])
	for entry: Array in _buildings().values():
		keep_clear.append_array(entry[4])
	var kept: Array = []
	for piece: Array in pieces:
		var at: Vector3 = piece[1]
		var area := _footprint(piece).grow(FURNITURE_CLEARANCE)
		var free := true
		for point: Vector3 in keep_clear:
			if absf(point.y - at.y) < 1.0 and area.has_point(Vector2(point.x, point.z)):
				free = false
				break
		if free:
			kept.append(piece)
	return kept


## The furniture stops bodies, sight and the navigation mesh like a low
## obstacle (S-016, Q7): a box around each model.
func _build_furniture() -> void:
	var s := kit.structure("Furniture")
	for piece: Array in _furniture_pieces():
		if FURNITURE_GHOSTS.has(piece[0]):
			continue
		var area := _footprint(piece)
		var at: Vector3 = piece[1]
		var height := _model_box(FURNITURE_MODELS[piece[0]]).end.y
		kit.box(
			s,
			area.position.x,
			area.position.y,
			area.end.x,
			area.end.y,
			at.y,
			at.y + height,
			null,
			MapKit.Kind.FLOOR
		)


func _add_furniture() -> void:
	var node: Node3D = FURNITURE_SCRIPT.new()
	node.name = "Furniture"
	_add(node)
	var counts := {}
	for piece: Array in _furniture_pieces():
		var key: String = piece[0]
		counts[key] = counts.get(key, 0) + 1
		var at: Vector3 = piece[1]
		var node_name := "%s%d" % [key.to_pascal_case(), counts[key]]
		var scale := Vector3(piece[3], 1, 1)
		_place_model(
			node, FURNITURE_MODELS[key], node_name, Vector2(at.x, at.z), piece[2], scale, at.y
		)
	# No navigation mesh on top of the low furniture either: the AIs would aim
	# for islands they cannot reach. Over the tall pieces, there is no room.
	var obstacles := _group("FurnitureObstacles")
	obstacles.add_to_group("navigation_source", true)
	for piece: Array in _furniture_pieces():
		if FURNITURE_GHOSTS.has(piece[0]):
			continue
		var height := _model_box(FURNITURE_MODELS[piece[0]]).end.y
		if height > FURNITURE_TALL:
			continue
		var area := _footprint(piece)
		var at: Vector3 = piece[1]
		var obstacle := NavigationObstacle3D.new()
		obstacle.position = kit.world(area.position.x, area.position.y, at.y - 0.1)
		obstacle.vertices = PackedVector3Array(
			[
				Vector3.ZERO,
				Vector3(area.size.x, 0, 0),
				Vector3(area.size.x, 0, area.size.y),
				Vector3(0, 0, area.size.y),
			]
		)
		obstacle.height = height + 0.6
		obstacle.affect_navigation_mesh = true
		obstacle.avoidance_enabled = false
		obstacles.add_child(obstacle)
		obstacle.owner = _root


## Wrecks, pillars, dead neons, the "P" sign and the garage doors (T-047).
func _add_car_park_dressing() -> void:
	var node := _group("CarParkDressing")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ceiling := -GROUND_THICKNESS
	for i in CAR_PARK_WRECKS.size():
		var turn := Vector2.UP if i % 2 == 0 else Vector2.DOWN
		_place_model(
			node, CAR_WRECK, "Wreck%d" % (i + 1), CAR_PARK_WRECKS[i], turn, Vector3.ONE, floor_h
		)
	var n := 0
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			n += 1
			_place_model(
				node,
				CAR_PARK_PILLAR,
				"Pillar%d" % n,
				Vector2(px, py),
				Vector2.UP,
				Vector3.ONE,
				floor_h
			)
		var neon := Vector2(px - CAR_PARK_PILLAR_STEP / 2.0, r.get_center().y)
		_place_model(node, NEON_FIXTURE, "Neon%d" % n, neon, Vector2.UP, Vector3.ONE, ceiling)
		px += CAR_PARK_PILLAR_STEP
	_place_model(node, CAR_PARK_SIGN, "SignP", Vector2(126.7, 99.5), Vector2.LEFT)
	# Garage doors on the east wall of the boxes, seen from the east.
	var g := GARAGES
	var width := g.size.y / GARAGE_COUNT
	for i in GARAGE_COUNT:
		var south := g.position.y + (i + 1) * width - 0.5
		var scene := GARAGE_OPEN if GARAGES_OPEN.has(i) else GARAGE_CLOSED
		_place_model(
			node,
			scene,
			"Garage%d" % (i + 1),
			Vector2(g.end.x + FACADE_OFFSET, south),
			Vector2.RIGHT
		)


## Transformer, playground and city stadium (T-048).
func _add_outdoor_dressing() -> void:
	var node := _group("OutdoorDressing")
	_place_model(node, TRANSFORMER, "Transformer", Vector2(100.5, 153.5), Vector2.UP)
	_place_model(node, SWING, "Swing", Vector2(61, 80.5), Vector2.UP)
	_place_model(node, CLIMBING_FRAME, "ClimbingFrame", Vector2(54.5, 74.5), Vector2.UP)
	_place_model(node, STADIUM_GOAL, "GoalWest", Vector2(149.5, 190), Vector2.RIGHT)
	_place_model(node, STADIUM_GOAL, "GoalEast", Vector2(176.5, 190), Vector2.LEFT)
	# Boards of the city stadium, facing out, around the openings (west, north).
	var runs := [
		[Vector2(160, 180), Vector2(148, 180), Vector2.UP],
		[Vector2(178, 180), Vector2(166, 180), Vector2.UP],
		[Vector2(148, 200), Vector2(178, 200), Vector2.DOWN],
		[Vector2(148, 180), Vector2(148, 188), Vector2.LEFT],
		[Vector2(148, 192), Vector2(148, 200), Vector2.LEFT],
		[Vector2(178, 200), Vector2(178, 180), Vector2.RIGHT],
	]
	# One MultiMesh per run: 45 separate boards would cost 90 draw calls.
	var boards: FacadeDressing = FACADE_DRESSING.new()
	boards.name = "StadiumBoards"
	boards.models.assign([STADIUM_BOARD])
	for r in runs.size():
		var from: Vector2 = runs[r][0]
		var to: Vector2 = runs[r][1]
		var normal: Vector2 = runs[r][2]
		var along := (to - from).normalized()
		var z_axis := Vector3(normal.x, 0, normal.y)
		var basis := Basis(Vector3.UP.cross(z_axis), Vector3.UP, z_axis)
		for i in roundi(from.distance_to(to) / STADIUM_BOARD_WIDTH):
			var at := from + along * (i * STADIUM_BOARD_WIDTH)
			boards.panels.append(Transform3D(basis, kit.world(at.x, at.y, 0.0)))
			boards.variants.append(0)
			boards.walls.append(r)
	node.add_child(boards)
	boards.owner = _root


## Wind everywhere, the motorway to the east, a train on the embankment now
## and then, the swing creaking (T-050). Plain players: none of them goes
## through NoiseBus, so they betray nobody.
func _add_ambience() -> void:
	var node := _group("Ambience")
	var wind := CityWind.new()  # Its gusts cut the small noises outdoors (S-012, T-144).
	wind.name = "Wind"
	wind.stream = WIND_SOUND
	wind.volume_db = -12.0
	wind.autoplay = true
	node.add_child(wind)
	wind.owner = _root
	for i in MOTORWAY_SOURCES.size():
		var road := _sound(
			node, "Motorway%d" % (i + 1), MOTORWAY_SOUND, Vector2(216, MOTORWAY_SOURCES[i]), 1.0
		)
		road.unit_size = 25.0
		road.max_distance = 150.0
		road.volume_db = -4.0
	var train: AudioStreamPlayer3D = AMBIENT_TRAIN.new()
	train.name = "Train"
	train.stream = TRAIN_SOUND
	train.unit_size = 40.0
	train.max_distance = 220.0
	train.track_start = kit.world(-40, 1, 7)
	train.track_end = kit.world(260, 1, 7)
	node.add_child(train)
	train.owner = _root
	var swing := _sound(node, "SwingCreak", SWING_SOUND, Vector2(61, 80.5), 2.0)
	swing.unit_size = 3.0
	swing.max_distance = 18.0


## Bakes the street lights and the landmark lights into the ground and the
## walls (T-049, plan B: no GPU for LightmapGI). Their real lights now only
## light the models, and fade out past LIGHT_FADE_BEGIN.
func _bake_light() -> void:
	var lights: Array[OmniLight3D] = []
	lights.assign(_root.get_node("Props").find_children("*", "OmniLight3D", true, false))
	var started := Time.get_ticks_msec()
	var space := _root.get_world_3d().direct_space_state
	var count := kit.bake_light(lights, space, MapKit.WORLD_LAYER | MapKit.WALLS_LAYER)
	print(
		(
			"Baked %d lights in %d vertices in %d ms"
			% [lights.size(), count, Time.get_ticks_msec() - started]
		)
	)


func _add_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	mesh.cell_size = 0.125
	# Lower than the monster (2.2 m): with cells 0.25 m high, a 2.4 m door
	# leaves less than 2.25 m of clearance on the voxel grid.
	mesh.agent_height = 2.0
	mesh.agent_radius = 0.375
	# Only inside the fences: no useless islands on the motorway or the wasteland.
	# The bottom sits just under a multiple of the cell height (0.25 m), so the
	# mesh lies about 0.26 m above floors at whole storeys: closer than the AI
	# agents' path_desired_distance (0.5 m), or they would never pass a path point.
	var lo := kit.world(FENCED.position.x, FENCED.position.y, NAV_BOTTOM)
	var hi := kit.world(FENCED.end.x, FENCED.end.y, 20)
	mesh.filter_baking_aabb = AABB(lo, hi - lo)
	region.navigation_mesh = mesh
	_root.add_child(region)
	region.owner = _root


func _add_gameplay() -> void:
	_root.set_script(MAP_SCRIPT)
	_add_loop()
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
	# Each hunted starts facing the tower, the landmark of the cité.
	var tower_center := kit.world(TOWER.get_center().x, TOWER.get_center().y)
	for marker: Node3D in spawns.get_children():
		var to := tower_center - marker.position
		marker.rotation.y = atan2(-to.x, -to.z)
	var monster_spawn := _markers("MonsterSpawn", [MONSTER_SPAWN])
	var patrol := _markers("PatrolRoute", PATROL_ROUTE)
	_markers("PreyRoute", PREY_ROUTE)
	_markers("HidingSpots", HIDING_SPOTS)
	_markers("GuardPoints", GUARD_POINTS)
	var monster: Node3D = _named(MONSTER.instantiate(), "Monster")
	monster.position = monster_spawn.get_child(0).position
	monster.set("patrol_route", patrol)
	monster.set("start_index", 0)
	_add(monster)
	_add(_named(NOISE_DEBUG.instantiate(), "NoiseDebug"))
	var player: Node3D = _named(PLAYER.instantiate(), "Player")
	player.transform = spawns.get_child(0).transform
	_add(player)
	var overlay := _named(OVERLAY.instantiate(), "DebugOverlay")
	overlay.set("player", player)
	overlay.set("monster", monster)
	_add(overlay)
	var gauge := _named(GAUGE.instantiate(), "NoiseGauge")
	gauge.set("player", player)
	_add(gauge)
	var prompt := _named(INTERACT_PROMPT.instantiate(), "InteractPrompt")
	prompt.set("player", player)
	_add(prompt)
	_add(_named(CAUGHT.instantiate(), "CaughtScreen"))
