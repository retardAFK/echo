extends GutTest
## Network objects against a wall or a floor (spec S-020, T-325, piste L2):
## PlacementCheck on the cité, so that a camera hanging in the air (T-315) or
## a keypad away from its wall (T-316) fails the CI.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const TERMINAL_SCENE := preload("res://game/entities/network/terminal.tscn")


func test_every_network_object_touches_a_wall_or_a_floor() -> void:
	var map: Node = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(3)
	var objects := PlacementCheck.objects(map)
	assert_gt(objects.size(), 20, "cameras, terminals, loudspeakers, relays")
	var offenders := PlacementCheck.offenders(map)
	assert_eq(offenders, [] as Array[String], "\n".join(offenders))


func test_an_object_in_the_air_is_reported() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10, 0.2, 10)
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.1, 0)
	add_child_autofree(floor_body)
	var terminal: Terminal = TERMINAL_SCENE.instantiate()
	add_child_autofree(terminal)
	await wait_physics_frames(2)
	assert_eq(PlacementCheck.offenders(self), [] as Array[String], "on the floor")
	terminal.position.y = 1.0
	await wait_physics_frames(2)
	assert_eq(PlacementCheck.offenders(self).size(), 1, "a meter up in the air")
	assert_almost_eq(PlacementCheck.gap(terminal), 1.0, 0.05)
