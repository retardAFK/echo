extends GutTest
## An AI body caught on a door jamb steps back, then walks on (S-016, T-243),
## aslant to one side then the other (T-167).

const STEP := 1.0 / 60.0


func _held_body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	add_child_autofree(body)
	return body  # Never moved: its real velocity stays zero.


func test_a_body_that_moves_keeps_its_way() -> void:
	var jamb := JambUnstick.new()
	var body := _held_body()
	var wanted := Vector3(3, 0, 0)
	assert_eq(jamb.update(body, wanted, STEP), wanted, "not held long enough yet")


func test_held_still_it_steps_back_then_walks_on() -> void:
	var jamb := JambUnstick.new()
	var body := _held_body()
	var wanted := Vector3(3, 0, 0)
	var way := wanted
	var held := 0.0
	while way == wanted and held < 1.0:
		way = jamb.update(body, wanted, STEP)
		held += STEP
	assert_almost_eq(held, JambUnstick.STUCK_TIME, 2 * STEP)
	assert_lt(way.x, 0.0, "steps back the way it came")
	var backing := 0.0
	while way.x < 0.0 and backing < 1.0:
		way = jamb.update(body, wanted, STEP)
		backing += STEP
	assert_almost_eq(backing, JambUnstick.BACK_TIME, 2 * STEP)
	assert_eq(way, wanted, "then walks on")


func test_standing_still_on_purpose_is_not_being_stuck() -> void:
	var jamb := JambUnstick.new()
	var body := _held_body()
	for i in 60:
		assert_eq(jamb.update(body, Vector3.ZERO, STEP), Vector3.ZERO)


func test_it_steps_back_aslant_one_side_then_the_other() -> void:
	var jamb := JambUnstick.new()
	var body := _held_body()
	var wanted := Vector3(3, 0, 0)
	var sides: Array[float] = []
	for i in 300:
		var way := jamb.update(body, wanted, STEP)
		if way.x < 0.0 and (sides.is_empty() or signf(way.z) != sides.back()):
			assert_ne(way.z, 0.0, "aslant, not straight back")
			sides.append(signf(way.z))
	assert_gte(sides.size(), 2)
	assert_eq(sides[0], -sides[1], "one side, then the other")
