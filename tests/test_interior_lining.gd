extends GutTest
## Interiors of the tower and the cellars with the mood of the hospital (S-019):
## lined rooms in one material, the decor of each storey in one draw call drawn
## near it only, a few live lamps baked like the street lights.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const MapKit := preload("res://tools/godot/map_kit.gd")
const LINING := preload("res://game/fx/materials/interior_lining.tres")
const InteriorLining := preload("res://tools/godot/interior_lining.gd")

var _map: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _lining_surfaces(node_path: String) -> int:
	var mesh: MeshInstance3D = _map.get_node(node_path)
	var count := 0
	for i in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_material(i) == LINING:
			count += 1
	return count


func test_the_tower_and_the_cellars_are_lined_in_one_draw_call_each() -> void:
	assert_eq(_lining_surfaces("Structures/Tower/Mesh"), 1)
	assert_eq(_lining_surfaces("Structures/Cellars/Mesh"), 1)
	# The blocks of flats seen from outside keep their concrete.
	assert_eq(_lining_surfaces("Structures/BarreA/Mesh"), 0)


func test_each_storey_has_its_decor_in_one_draw_call_drawn_near_it() -> void:
	var decor := _map.get_node("InteriorDecor")
	assert_eq(decor.get_child_count(), 6, "5 storeys and the cellars")
	for node: MeshInstance3D in decor.get_children():
		assert_eq(node.mesh.get_surface_count(), 1, node.name)
		assert_gt(node.visibility_range_end, 0.0, node.name)
		assert_lte(node.visibility_range_end, 20.0, node.name)


func test_live_lamps_are_few_baked_and_never_orange() -> void:
	var lamps := _map.get_node("Props/InteriorLights").get_children()
	assert_between(lamps.size(), 5, 20)
	for light: OmniLight3D in lamps:
		assert_eq(light.light_cull_mask & MapKit.BAKED_LAYER, 0, light.name)
		assert_true(light.distance_fade_enabled, light.name)
		assert_lte(light.omni_range, 6.0, light.name)
		# Orange is the noise color (constitution 2.3): no warm hue that strong.
		var c := light.light_color
		assert_false(c.r > 0.9 and c.g < 0.8 and c.b < 0.5, "%s is orange" % light.name)


func test_a_face_takes_the_tile_of_the_room_it_looks_into() -> void:
	var kit := MapKit.new()
	kit.origin = Vector2.ZERO
	kit.lining = LINING
	var wall := StandardMaterial3D.new()
	kit.lined_materials.assign([wall])
	kit.zone(
		Rect2(0, 0, 4, 4), 0.0, 3.0, InteriorLining.Tile.LIVING, InteriorLining.Tile.PARQUET, -1
	)
	kit.zone(Rect2(4, 0, 4, 4), 0.0, 3.0, InteriorLining.Tile.KITCHEN, InteriorLining.Tile.LINO, -1)
	var s: MapKit.Structure = kit.structure("Test")
	# A partition between the two rooms, longer than both, and a floor under them.
	kit.box(s, 3.9, -2.0, 4.1, 6.0, 0.0, 3.0, wall)
	kit.box(s, 0.0, 0.0, 8.0, 4.0, -0.3, 0.0, wall, MapKit.Kind.FLOOR)
	var tiles := {}
	for block in s.blocks:
		for part in kit._faces(block):
			var key := "%s %s" % [Vector3i(part.normal.round()), part.tile]
			tiles[key] = tiles.get(key, 0.0) + part.u_len * part.v_len
	# West face of the partition: living room inside the zone, concrete outside
	# (and the 1.2 m² west edge of the floor).
	assert_almost_eq(tiles["(-1, 0, 0) %d" % InteriorLining.Tile.LIVING], 12.0, 0.01)
	assert_almost_eq(tiles["(-1, 0, 0) -1"], 13.2, 0.01)
	assert_almost_eq(tiles["(1, 0, 0) %d" % InteriorLining.Tile.KITCHEN], 12.0, 0.01)
	# The floor: parquet on one side, lino on the other; no ceiling tile below.
	assert_almost_eq(tiles["(0, 1, 0) %d" % InteriorLining.Tile.PARQUET], 16.0, 0.01)
	assert_almost_eq(tiles["(0, 1, 0) %d" % InteriorLining.Tile.LINO], 16.0, 0.01)
	assert_false(tiles.has("(0, -1, 0) %d" % InteriorLining.Tile.CEILING))
