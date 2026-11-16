extends GutTest
## The inside of the buildings is drawn only on the levels near the camera
## (S-014, Q12, T-195): no occlusion culling, so the doors and furniture of
## the other storeys cost draw calls behind the slabs.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
## Plan point (x, height, y) of the second-floor landing of the tower.
const LANDING_2 := Vector3(94, 7.6, 100)
const STREET := Vector3(105, 1.6, 128)

var _map: GameMap
var _camera: Camera3D
var _visibility: LevelVisibility


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_camera = Camera3D.new()
	_map.add_child(_camera)
	_camera.make_current()
	for node in _map.get_children():
		if node is LevelVisibility:
			_visibility = node
	await wait_physics_frames(2)


## World position of a plan point, as the map builder places it.
func _world(plan: Vector3) -> Vector3:
	return Vector3(plan.x - 110.0, plan.y, plan.z - 110.0)


func _look_from(plan: Vector3) -> void:
	_camera.global_position = _world(plan)
	await wait_seconds(LevelVisibility.PERIOD * 3)


## Tower doors at a level: drawn and hidden counts.
func _tower_doors(level: int) -> Vector2i:
	var tower: Building = _map.get_node("Buildings/Tower")
	var counts := Vector2i.ZERO
	for door: Door in get_tree().get_nodes_in_group(Door.GROUP):
		for node in door.find_children("*", "GeometryInstance3D", true, false):
			var model := node as GeometryInstance3D
			var at := model.global_transform * model.get_aabb()
			var foot := at.get_center()
			foot.y = at.position.y + LevelVisibility.FOOT
			if not tower.contains(foot) or LevelVisibility.level_of(foot.y) != level:
				continue
			if model.layers == 0:
				counts.y += 1
			else:
				counts.x += 1
	return counts


func test_the_rules() -> void:
	assert_true(LevelVisibility.shows(-1, 0, 2, 0), "outside: ground floors")
	assert_true(LevelVisibility.shows(-1, 0, 2, -1), "outside: the car park ramp")
	assert_false(LevelVisibility.shows(-1, 0, 2, 3), "outside: not the third floor")
	assert_true(LevelVisibility.shows(0, 2, 0, 3), "inside: the storey above")
	assert_false(LevelVisibility.shows(0, 2, 0, 4), "inside: not two storeys up")
	assert_false(LevelVisibility.shows(0, 2, 1, 0), "inside: not another building's ground floor")
	assert_true(LevelVisibility.shows(0, -1, 1, -1), "the cellars see the car park")
	assert_eq(LevelVisibility.level_of(0.2), 0)
	assert_eq(LevelVisibility.level_of(6.1), 2)
	assert_eq(LevelVisibility.level_of(-2.9), -1)


func test_a_landing_hides_the_far_storeys_of_the_tower() -> void:
	assert_not_null(_visibility)
	await _look_from(LANDING_2)
	var here := _tower_doors(2)
	assert_gt(here.x, 0, "doors of the landing drawn")
	assert_eq(here.y, 0, "no door of the landing hidden")
	assert_gt(_tower_doors(4).y, 0, "fourth floor doors hidden")
	assert_eq(_tower_doors(4).x, 0, "no fourth floor door drawn")
	assert_gt(_tower_doors(0).y, 0, "ground floor doors hidden")


func test_outside_everything_comes_back_but_the_upper_storeys() -> void:
	await _look_from(LANDING_2)
	await _look_from(STREET)
	assert_eq(_tower_doors(0).y, 0, "ground floor doors drawn again")
	assert_eq(_tower_doors(1).y, 0, "first floor doors drawn again")
	assert_gt(_tower_doors(4).y, 0, "fourth floor doors hidden from the street")


func test_hidden_models_keep_their_collisions_and_nodes() -> void:
	await _look_from(LANDING_2)
	assert_gt(_visibility.hidden_count(), 20)
	for door: Door in get_tree().get_nodes_in_group(Door.GROUP):
		assert_true(door.visible, str(door.name))
