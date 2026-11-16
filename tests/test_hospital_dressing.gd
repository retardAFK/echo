extends GutTest
## The look of the hospital (spec S-014, T-189, T-190): its tiles in the
## interior atlas, its furniture from tools/blender/hospital_kit.py, the tubes
## that stutter and the fog of its corridors.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const LINING := preload("res://game/fx/materials/interior_lining.tres")
const InteriorLining := preload("res://tools/godot/interior_lining.gd")
const Hospital := preload("res://tools/godot/hospital.gd")
const NEON_SCENE := preload("res://game/entities/neon/neon_tube.tscn")
const SETTINGS := preload("res://game/data/visual_settings.tres")
const ORIGIN := Vector3(110, 0, 110)

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _world(x: float, h: float, y: float) -> Vector3:
	return Vector3(x, h, y) - ORIGIN


func test_the_atlas_has_room_for_the_hospital_tiles() -> void:
	var grid: Vector2 = LINING.get_meta(&"atlas_grid")
	assert_eq(grid, Vector2(4, 4))
	assert_eq(InteriorLining.Tile.size(), 16, "the shader reads index / 15")
	var atlas: Texture2D = LINING.albedo_texture
	assert_eq(atlas.get_size(), Vector2(1024, 768), "4 x 4 tiles of 256 x 192")


func test_every_room_of_the_hospital_has_its_tiles() -> void:
	for h: float in Hospital.LEVELS:
		var tiles: Array = Hospital.ROOM_TILES[h]
		assert_eq(tiles[0].size(), Hospital.WEST_ROOMS[h].size(), "west, level %s" % h)
		assert_eq(tiles[1].size(), Hospital.EAST_ROOMS[h].size(), "east, level %s" % h)
		for side: Array in tiles:
			for pair: Array in side:
				assert_true(InteriorLining.Tile.has(pair[0]), pair[0])
				assert_true(InteriorLining.Tile.has(pair[1]), pair[1])


func test_the_hospital_is_furnished() -> void:
	var counts := {}
	for piece in _map.get_node("Furniture").get_children():
		var key := String(piece.name).rstrip("0123456789")
		counts[key] = counts.get(key, 0) + 1
	assert_gt(counts.get("HospitalBed", 0), 15, "the wards and intensive care")
	assert_eq(counts.get("MorgueDrawers", 0), 1)
	assert_gt(counts.get("Curtain", 0), 0, "between the emergency boxes")
	assert_gt(counts.get("IvPole", 0), 3)


func test_the_ambulance_is_the_car_alarm_under_the_canopy() -> void:
	var car: CarAlarm = _map.get_node("CarAlarms/Car5")
	assert_not_null(car.get_node_or_null("Model"))
	assert_eq(car.scene_file_path, "res://game/entities/car_alarm/ambulance_alarm.tscn")
	var canopy := Hospital.CANOPY
	var at := car.global_position + ORIGIN
	assert_true(canopy.has_point(Vector2(at.x, at.z)), "under the canopy")


func test_the_gurney_wheelchair_and_monitor_wear_their_models() -> void:
	for path: String in ["Rolling/Gurney1", "Rolling/Wheelchair1", "Monitors/Monitor1"]:
		var meshes := _map.get_node(path).find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, path)


func test_three_tubes_stutter() -> void:
	assert_eq(_map.get_node("Neons").get_child_count(), Hospital.NEONS.size())
	for neon in _map.get_node("Neons").get_children():
		assert_true(neon is NeonTube)


func test_a_tube_is_mostly_lit_and_sometimes_flickers() -> void:
	var neon: NeonTube = NEON_SCENE.instantiate()
	add_child_autofree(neon)
	neon.set_process(false)
	var lit_time := 0.0
	var changes := 0
	var was := neon.lit
	for i in 6000:  # A minute, in steps of 10 ms.
		neon.step(0.01)
		if neon.lit:
			lit_time += 0.01
		if neon.lit != was:
			changes += 1
			was = neon.lit
	assert_gt(lit_time, 40.0, "lit most of the time")
	assert_gt(changes, 6, "it stutters")


func test_the_fog_thickens_in_the_corridors() -> void:
	var corridor := _world(21.0, 1.5, 94.0)
	assert_true(IndoorFog.covers(get_tree(), corridor))
	assert_true(IndoorFog.covers(get_tree(), _world(21.0, 4.5, 70.0)), "1st floor")
	assert_false(IndoorFog.covers(get_tree(), _world(14.0, 1.5, 94.0)), "a room")
	assert_false(IndoorFog.covers(get_tree(), _world(40.0, 1.5, 94.0)), "outside")


func test_the_night_turns_to_indoor_fog() -> void:
	var night := NightEnvironment.new()
	night.environment = Environment.new()
	add_child_autofree(night)
	night.set_process(false)
	assert_almost_eq(night.environment.fog_density, SETTINGS.fog_density, 0.0001)
	night.indoor = 1.0
	night.set_scan_amount(0.0)
	assert_almost_eq(night.environment.fog_density, SETTINGS.indoor_fog_density, 0.0001)
	assert_eq(night.environment.fog_light_color, SETTINGS.indoor_fog_color)
	night.set_scan_amount(1.0)
	assert_lt(night.environment.fog_light_color.v, SETTINGS.indoor_fog_color.v, "the scan dims it")
