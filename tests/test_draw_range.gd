extends GutTest
## Doors, hiding spots, fuse boxes and pickups are drawn only near the camera
## (S-016, T-244): the map has no occlusion culling, and behind the walls they
## cost about a hundred draw calls (constitution 2.2: 300 at worst).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _models(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		found.append(node as GeometryInstance3D)
	return found


func test_every_door_spot_box_and_pickup_has_a_draw_range() -> void:
	var things: Array[Node] = []
	things.append_array(get_tree().get_nodes_in_group(Door.GROUP))
	things.append_array(get_tree().get_nodes_in_group(HidingSpot.GROUP))
	things.append_array(_map.get_fuse_boxes())
	things.append_array(_map.get_node("Pickups").find_children("*", "Pickup", true, false))
	assert_gt(things.size(), 100)
	for thing in things:
		var models := _models(thing)
		assert_gt(models.size(), 0, str(thing.name))
		for model in models:
			assert_gt(model.visibility_range_end, 0.0, "%s/%s" % [thing.name, model.name])


func test_inner_doors_are_drawn_nearer_than_outer_ones() -> void:
	var inner := 0
	var outer := 0
	for door: Door in get_tree().get_nodes_in_group(Door.GROUP):
		var model := _models(door)[0]
		if door.indoor:
			inner += 1
			assert_eq(model.visibility_range_end, DrawRange.INDOOR, str(door.name))
		else:
			outer += 1
			assert_eq(model.visibility_range_end, DrawRange.OUTDOOR, str(door.name))
	assert_gt(inner, 40, "flats, offices, back rooms")
	assert_gt(outer, 10, "entrances, emergency exits, shutters")
