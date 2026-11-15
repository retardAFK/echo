extends GutTest
## The gallery of the Tilleuls (spec S-016, T-238): five shops open at the
## back, a delivery corridor open at both ends, a shutter to roll up, a bell,
## steep metal stairs up to the roof.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)
const REACH := 1.0
const PLACES := {
	"pharmacy": Vector3(49, 0, 141),
	"laundrette": Vector3(58, 0, 142),
	"tobacconist": Vector3(64.5, 0, 144),
	"grocer": Vector3(74, 0, 145),
	"baker": Vector3(82, 0, 145),
	"corridor": Vector3(66, 0, 148),
	"roof": Vector3(66, 3.8, 142),
}

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _world(plan: Vector3) -> Vector3:
	return plan - ORIGIN


func _nav_map() -> RID:
	var nav_map := _map.get_world_3d().navigation_map
	var spawn: Vector3 = _map.get_spawn_points()[0]
	await wait_until(func() -> bool: return NavigationServer3D.map_get_iteration_id(nav_map) > 0, 5)
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, spawn)
			return Vector2(closest.x, closest.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.1,
		5
	)
	return nav_map


func _doors_near(plan: Vector3, radius: float) -> Array[Door]:
	var found: Array[Door] = []
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if _map.is_ancestor_of(door) and door.global_position.distance_to(_world(plan)) < radius:
			found.append(door)
	return found


func test_every_shop_the_corridor_and_the_roof_can_be_reached() -> void:
	var nav_map: RID = await _nav_map()
	var start: Vector3 = _map.get_spawn_points()[0]
	for place: String in PLACES:
		var to := _world(PLACES[place])
		var path := NavigationServer3D.map_get_path(nav_map, start, to, true)
		assert_gt(path.size(), 1, place)
		if path.size() > 1:
			var end := path[path.size() - 1]
			assert_lt(Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)), REACH, place)
			assert_lt(absf(end.y - to.y), REACH, place)


func test_the_shop_fronts() -> void:
	var tobacconist := _doors_near(Vector3(65.8, 0, 139), 0.3)
	assert_eq(tobacconist.size(), 1)
	if tobacconist.size() == 1:
		assert_eq(tobacconist[0].kind, Door.Kind.SHUTTER, "a shutter to roll up")
	var baker := _doors_near(Vector3(81.2, 0, 139), 0.3)
	assert_eq(baker.size(), 1)
	if baker.size() == 1:
		assert_true(baker[0].bell, "the baker's bell")
	assert_eq(_doors_near(Vector3(56.6, 0, 139), 1.0).size(), 2, "the laundrette, double")
	assert_eq(_doors_near(Vector3(46.4, 0, 139), 0.3).size(), 1, "the pharmacy")


func test_every_shop_opens_onto_the_corridor() -> void:
	for i in 5:
		var at := 45.0 + i * 8.4 + 6.1
		assert_eq(_doors_near(Vector3(at, 0, 147), 0.3).size(), 1, "shop %d" % (i + 1))


func test_the_corridor_opens_at_both_ends() -> void:
	var east := _doors_near(Vector3(86.85, 0, 147.95), 0.3)
	var west := _doors_near(Vector3(45.15, 0, 147.95), 0.3)
	assert_eq(east.size(), 1)
	assert_eq(west.size(), 1)
	if east.size() == 1 and west.size() == 1:
		assert_eq(east[0].kind, Door.Kind.FIRE)
		assert_eq(west[0].kind, Door.Kind.EMERGENCY)
		var inside := Node3D.new()
		add_child_autofree(inside)
		inside.global_position = _world(Vector3(47, 0, 148))
		assert_true(west[0].can_use(inside), "opens from the corridor")
		inside.global_position = _world(Vector3(43, 0, 148))
		assert_false(west[0].can_use(inside), "not from outside")


func test_the_roof_stairs_are_metal() -> void:
	var tree := get_tree()
	assert_true(MetalFloor.under(tree, _world(Vector3(63, 1.9, 149.6))), "behind")
	assert_true(MetalFloor.under(tree, _world(Vector3(87.6, 1.9, 142))), "east")
	assert_false(MetalFloor.under(tree, _world(Vector3(66, 0, 148))), "the corridor")


func test_spots_of_every_family_in_the_gallery() -> void:
	var gallery: Building = _map.get_node("Buildings/Gallery")
	var families := {}
	for spot: HidingSpot in _map.get_node("Hideouts").get_children():
		if gallery.contains(spot.global_position + Vector3.UP * 0.5):
			families[spot.family] = families.get(spot.family, 0) + 1
	assert_eq(families.get(HidingSpot.Family.CLOSET, 0), 3)
	assert_eq(families.get(HidingSpot.Family.LOW, 0), 1)
	assert_eq(families.get(HidingSpot.Family.MAKESHIFT, 0), 1)
	assert_eq(families.get(HidingSpot.Family.METAL, 0), 2)
