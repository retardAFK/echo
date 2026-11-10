extends GutTest
## Light of the street lamps and landmarks baked in the vertices (spec S-006,
## T-049, plan B): the meshes carry it, the real lights skip them and fade out.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const MapKit := preload("res://tools/godot/map_kit.gd")

var _map: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _baked_lights() -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	lights.assign(_map.get_node("Props").find_children("*", "OmniLight3D", true, false))
	return lights


func _structure_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for group in ["Ground", "Structures"]:
		for mesh: MeshInstance3D in _map.get_node(group).find_children(
			"Mesh", "MeshInstance3D", true, false
		):
			meshes.append(mesh)
	return meshes


func test_real_lights_leave_the_baked_meshes_alone() -> void:
	var meshes := _structure_meshes()
	assert_gt(meshes.size(), 50)
	for mesh in meshes:
		assert_eq(mesh.layers, MapKit.BAKED_LAYER, str(mesh.get_path()))
	var lights := _baked_lights()
	assert_gt(lights.size(), 20, "lampposts and landmark lights")
	for light in lights:
		assert_eq(light.light_cull_mask & MapKit.BAKED_LAYER, 0, light.name)


func test_real_lights_fade_out_but_the_tower_beacon() -> void:
	for light in _baked_lights():
		assert_eq(light.distance_fade_enabled, light.name != "TowerBeacon", light.name)
		if light.distance_fade_enabled:
			assert_lte(light.distance_fade_begin + light.distance_fade_length, 25.0, light.name)


func test_the_ground_under_each_lamppost_is_lit_orange() -> void:
	var ground: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in _map.get_node("Ground").find_children(
		"Mesh", "MeshInstance3D", true, false
	):
		ground.append(mesh)
	var lampposts := 0
	for light in _baked_lights():
		if light.name != "SodiumLight":
			continue
		lampposts += 1
		var foot := light.global_position
		foot.y = 0.0
		var best := _nearest_top_vertex(ground, foot)
		assert_lt(best[0], 0.8, "a vertex near the foot of %s" % light.get_parent().name)
		var color: Color = best[1]
		assert_gt(color.r, 0.2, light.get_parent().name)
		assert_gt(color.r, color.b * 2.0, "sodium orange")
	assert_gt(lampposts, 10)


func test_baked_light_stays_in_range() -> void:
	var brightest := 0.0
	for mesh in _structure_meshes():
		for i in mesh.mesh.get_surface_count():
			var custom = mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_CUSTOM0]
			if custom == null:
				continue
			for value: float in custom:
				brightest = maxf(brightest, value)
	assert_gt(brightest, 0.2)
	assert_lt(brightest, 3.0, "no burnt white spot")


## [distance, color] of the upward-facing ground vertex nearest to a point.
func _nearest_top_vertex(meshes: Array[MeshInstance3D], at: Vector3) -> Array:
	var best := [INF, Color.BLACK]
	for mesh in meshes:
		for i in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(i)
			var custom = arrays[Mesh.ARRAY_CUSTOM0]
			if custom == null:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for v in vertices.size():
				if normals[v].y < 0.9:
					continue
				var d := (mesh.global_transform * vertices[v]).distance_to(at)
				if d < best[0]:
					best = [d, Color(custom[v * 3], custom[v * 3 + 1], custom[v * 3 + 2])]
	return best
