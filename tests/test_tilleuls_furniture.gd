extends GutTest
## The furniture of the interiors (spec S-016, Q7, T-241): flats, social
## centre, gallery and car park furnished, never on a hiding spot, a fuse box
## or a pickup, and drawn only near the camera.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
## Pieces that only show: the stage curtain, the lift doors on their shaft.
const GHOSTS := ["StageCurtain", "LiftDoors"]

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _pieces() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for child in _map.get_node("Furniture").get_children():
		found.append(child as Node3D)
	return found


## The box around a node's meshes, in world space.
func _box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _is_ghost(piece: Node) -> bool:
	for ghost: String in GHOSTS:
		if piece.name.begins_with(ghost):
			return true
	return false


func test_every_visited_building_is_furnished() -> void:
	var counts := {}
	for piece in _pieces():
		for building: Building in _map.get_node("Buildings").get_children():
			if building.contains(piece.global_position + Vector3.UP * 0.3):
				counts[String(building.name)] = counts.get(String(building.name), 0) + 1
	assert_gt(counts.get("Tower", 0), 40, "four flats on each of four storeys")
	assert_gt(counts.get("SocialCentre", 0), 5)
	assert_gt(counts.get("Gallery", 0), 5)
	assert_gt(counts.get("CarPark", 0), 0)


func test_the_flats_have_beds_sofas_tables_and_fridges() -> void:
	var kinds := {}
	for piece in _pieces():
		var kind := piece.name.rstrip("0123456789")
		kinds[kind] = kinds.get(kind, 0) + 1
	for kind: String in ["Bed", "Sofa", "KitchenTable", "Fridge", "Boxes"]:
		assert_gt(kinds.get(kind, 0), 6, kind)


func test_furniture_is_drawn_only_near_the_camera() -> void:
	for piece in _pieces():
		for child in piece.find_children("*", "GeometryInstance3D", true, false):
			assert_gt((child as GeometryInstance3D).visibility_range_end, 0.0, str(piece.name))


func test_furniture_stands_on_no_spot_fuse_box_or_pickup() -> void:
	var things: Array[Node3D] = []
	for spot in _map.get_node("Hideouts").get_children():
		things.append(spot as Node3D)
	for box in _map.get_node("FuseSlots").find_children("FuseBox", "", true, false):
		things.append(box as Node3D)
	for pickup in _map.get_node("Pickups").find_children("*", "", true, false):
		if pickup is RigidBody3D or pickup.get_parent().get_parent() == _map.get_node("Pickups"):
			things.append(pickup as Node3D)
	for piece in _pieces():
		if _is_ghost(piece):
			continue
		var box := _box(piece)
		for thing in things:
			var at := thing.global_position
			var inside := (
				at.x > box.position.x - 0.2
				and at.x < box.end.x + 0.2
				and at.z > box.position.z - 0.2
				and at.z < box.end.z + 0.2
				and at.y > box.position.y - 1.0
				and at.y < box.end.y
			)
			assert_false(inside, "%s on %s" % [piece.name, thing.name])


func test_furniture_blocks_bodies() -> void:
	var space := _map.get_world_3d().direct_space_state
	await wait_physics_frames(2)
	var blocked := 0
	for piece in _pieces():
		if _is_ghost(piece):
			continue
		var query := PhysicsPointQueryParameters3D.new()
		query.position = _box(piece).get_center()
		query.collision_mask = 1
		if not space.intersect_point(query, 1).is_empty():
			blocked += 1
	assert_eq(blocked, _pieces().filter(func(p: Node3D) -> bool: return not _is_ghost(p)).size())
