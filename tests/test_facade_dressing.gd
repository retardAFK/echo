extends GutTest
## Facade modules on the blocks of flats and the tower (spec S-006, T-045).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)
## Module order of FacadeDressing.models (build_tilleuls.gd).
const DOOR := 4
const OPEN := 5
const TOWER := Rect2(92, 88, 24, 24)

var _map: Node3D
var _dressing: FacadeDressing


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_dressing = _map.get_node("FacadeDressing")


func _plan(at: Vector3) -> Vector2:
	return Vector2(at.x + ORIGIN.x, at.z + ORIGIN.z)


func test_every_panel_is_drawn_by_a_multimesh() -> void:
	await wait_process_frames(2)
	var drawn := 0
	for batch: MultiMeshInstance3D in _dressing.find_children(
		"*", "MultiMeshInstance3D", true, false
	):
		drawn += batch.multimesh.instance_count
	assert_gt(_dressing.panels.size(), 1000)
	assert_eq(drawn, _dressing.panels.size())


func test_panels_use_the_retro_surface() -> void:
	await wait_process_frames(3)
	var batch: MultiMeshInstance3D = (
		_dressing.find_children("*", "MultiMeshInstance3D", true, false)[0]
	)
	assert_true(batch.multimesh.mesh.surface_get_material(0) is ShaderMaterial)


func test_every_block_of_flats_is_dressed_on_its_four_sides() -> void:
	# 7 blocks and the tower, four walls each.
	var walls := {}
	for wall in _dressing.walls:
		walls[wall] = true
	assert_eq(walls.size(), 32)


func test_blocks_of_flats_have_entrance_doors() -> void:
	assert_gt(_dressing.count_of(DOOR), 14, "about one door every 18 m")
	for i in _dressing.panels.size():
		if _dressing.variants[i] == DOOR:
			assert_almost_eq(
				_dressing.panels[i].origin.y, 0.0, 0.01, "doors are on the ground floor"
			)


func test_visited_storeys_of_the_tower_have_open_windows() -> void:
	# 4 storeys above the hall, 8 modules on each of the 4 sides.
	assert_eq(_dressing.count_of(OPEN), 128)
	for i in _dressing.panels.size():
		if _dressing.variants[i] != OPEN:
			continue
		var at := _dressing.panels[i].origin
		assert_true(TOWER.grow(0.1).has_point(_plan(at)), "open window on the tower")
		assert_between(at.y, 2.9, 12.1)


func test_hall_entrances_of_the_tower_stay_free() -> void:
	for i in _dressing.panels.size():
		var panel := _dressing.panels[i]
		if panel.origin.y > 0.1:
			continue
		# The middle of the panel, along its wall.
		var mid := _plan(panel.origin + panel.basis.x * 1.5)
		var north := absf(mid.y - TOWER.position.y) < 0.2 and mid.x > 106 and mid.x < 110
		var south := absf(mid.y - TOWER.end.y) < 0.2 and mid.x > 102 and mid.x < 108
		assert_false(north or south, "no panel in front of the hall at %s" % mid)


func test_panels_have_no_collision() -> void:
	assert_eq(_dressing.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_gallery_has_its_shop_fronts_and_machines() -> void:
	var gallery := _map.get_node("GalleryDressing")
	assert_eq(gallery.find_children("Shop*", "", false, false).size(), 5)
	assert_eq(gallery.find_children("Washers*", "", false, false).size(), 4)
	assert_eq(gallery.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_half_shutter_matches_the_opening_of_the_greybox() -> void:
	# The 4th shop, its opening from 72.2 to 75.2 m on the plan (2 to 5 m from
	# its west end); the model's opening is 3.4 to 6.4 m from its east end.
	var shop: Node3D = _map.get_node("GalleryDressing/Shop4")
	var west := _plan(shop.global_transform * Vector3(6.4, 0, 0)).x
	var east := _plan(shop.global_transform * Vector3(3.4, 0, 0)).x
	assert_almost_eq(west, 72.2, 0.01)
	assert_almost_eq(east, 75.2, 0.01)


func test_social_centre_has_window_frames_and_its_entrance() -> void:
	var centre := _map.get_node("SocialCentreDressing")
	assert_eq(centre.find_children("Window*", "", false, false).size(), 10)
	assert_not_null(centre.get_node_or_null("Entrance"))
	assert_eq(centre.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_car_park_has_its_wrecks_pillars_and_sign() -> void:
	var car_park := _map.get_node("CarParkDressing")
	assert_eq(car_park.find_children("Wreck*", "", false, false).size(), 3)
	assert_eq(car_park.find_children("Pillar*", "", false, false).size(), 8)
	assert_not_null(car_park.get_node_or_null("SignP"))
	assert_eq(car_park.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_open_garages_have_open_doors() -> void:
	var car_park := _map.get_node("CarParkDressing")
	for i in 6:
		var garage: Node3D = car_park.get_node("Garage%d" % (i + 1))
		var open := garage.scene_file_path.ends_with("garage_open.glb")
		assert_eq(open, i == 1 or i == 4, "garage %d" % (i + 1))
