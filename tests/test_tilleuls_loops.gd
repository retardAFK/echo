extends GutTest
## Chase loops of the cité (spec S-020, T-341, piste E7, validated by Maxime
## on 20/11/2026): each obstacle stops bodies between opposite sides of its
## loop, the aisles around it are free both ways, and a lap is 12 to 25 m
## or so. The loops are listed in tools/godot/tilleuls_layout.gd (LOOPS).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const LAYOUT := preload("res://tools/godot/tilleuls_layout.gd")
## Plan coordinates to the world (map_kit.gd, origin at the middle).
const ORIGIN := Vector2(110, 110)
## The map's walls, ground and floors (MapKit layers).
const MASK := 1 | (1 << 1)
## A free aisle: the way from one point to the next is at most this much
## longer than the straight line, plus a meter.
const DETOUR := 1.6
## Laps, in meters: the plan's 12 to 25 m, with the points' own margin
## (they stand in the middle of the aisles, not along the obstacle).
const SHORTEST := 11.0
const LONGEST := 28.0

var _map: Node3D
var _nav: RID


func before_all() -> void:
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_nav = _map.get_world_3d().navigation_map
	var probe := _world(LAYOUT.LOOPS[0][2][0], LAYOUT.LOOPS[0][1])
	for i in 300:  # The navigation server syncs its map in the background.
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(_nav) == 0:
			continue
		if NavigationServer3D.map_get_closest_point(_nav, probe) != Vector3.ZERO:
			break


func after_all() -> void:
	_map.free()


func _world(point: Vector2, h: float) -> Vector3:
	return Vector3(point.x - ORIGIN.x, h, point.y - ORIGIN.y)


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_nav, from, to, true, 1)


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func test_there_are_the_seven_validated_loops() -> void:
	var names: Array[String] = []
	for loop: Array in LAYOUT.LOOPS:
		names.append((loop[0] as String).get_slice(" ", 0))
	for wanted in ["C1", "C2", "G1", "P1", "P2", "H1", "H2"]:
		assert_has(names, wanted)


func test_each_obstacle_stops_bodies_across_its_loop() -> void:
	var space := _map.get_world_3d().direct_space_state
	for loop: Array in LAYOUT.LOOPS:
		var points: Array = loop[2]
		for i in 2:
			var a := _world(points[i], loop[1]) + Vector3.UP
			var b := _world(points[i + 2], loop[1]) + Vector3.UP
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, MASK))
			assert_false(
				hit.is_empty(), "%s: something between points %d and %d" % [loop[0], i, i + 2]
			)


func test_each_loop_runs_both_ways_in_free_aisles() -> void:
	for loop: Array in LAYOUT.LOOPS:
		var points: Array = loop[2]
		for way: int in [1, -1]:
			var lap := 0.0
			for i in points.size():
				var a := _world(points[i], loop[1])
				var b := _world(points[posmod(i + way, points.size())], loop[1])
				var path := _path(a, b)
				var reached := path.size() > 0 and path[-1].distance_to(b) < 0.6
				assert_true(reached, "%s: from point %d, way %d" % [loop[0], i, way])
				var length := _length(path)
				var straight := a.distance_to(b)
				var free := length <= straight * DETOUR + 1.0
				assert_true(free, "%s: %.1f m for %.1f m straight" % [loop[0], length, straight])
				lap += length
			gut.p("%s, way %d: lap %.1f m" % [loop[0], way, lap])
			assert_between(lap, SHORTEST, LONGEST, "%s: lap" % loop[0])
