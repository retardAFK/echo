extends GutTest
## The greybox test map (spec S-001, T-005).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
# Constitution 2.2 allows 300 draw calls; the test map must stay far below.
const MAX_MESHES := 60

var _map: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func test_player_spawns_on_floor() -> void:
	var player: Player = _map.get_node("Player")
	await wait_physics_frames(60)
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, 0.0, 0.05)


func test_map_stays_light() -> void:
	var meshes := _map.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	assert_lt(meshes.size(), MAX_MESHES)


func test_every_mesh_has_a_collision() -> void:
	for mesh: MeshInstance3D in _map.find_children("*", "MeshInstance3D", true, false):
		assert_true(mesh.get_parent() is StaticBody3D, "%s must be solid" % mesh.name)
