extends GutTest
## Chase statistics of the end screen (spec S-020, T-322, piste E8):
## ChaseStats counts, ChaseWatch says whether the monster sees a hunted.

const SETTINGS := preload("res://game/data/chase_settings.tres")


## A body with eyes, like the monster and the hunted.
class Body:
	extends CharacterBody3D

	func get_eye_position() -> Vector3:
		return global_position + Vector3.UP * 1.6


func _stats() -> ChaseStats:
	return ChaseStats.new(SETTINGS)


func test_a_chase_starts_when_the_monster_sees_a_free_hunted_close() -> void:
	var stats := _stats()
	stats.step(1, 0.1, SETTINGS.start_range + 1.0, true, false)
	assert_eq(stats.chase_count, 0, "too far")
	stats.step(1, 0.1, 5.0, false, false)
	assert_eq(stats.chase_count, 0, "not seen")
	stats.step(1, 0.1, 5.0, true, true)
	assert_eq(stats.chase_count, 0, "captured")
	stats.step(1, 0.1, 5.0, true, false)
	assert_eq(stats.chase_count, 1)
	assert_true(stats.is_chased(1))
	stats.step(1, 0.1, 5.0, true, false)
	assert_eq(stats.chase_count, 1, "the same chase goes on")


func test_out_of_sight_long_enough_is_a_successful_escape() -> void:
	var stats := _stats()
	stats.step(1, 0.1, 5.0, true, false)
	var steps := int(SETTINGS.escape_time / 0.5)
	for i in steps - 1:
		stats.step(1, 0.5, 9.0, false, false)
	stats.step(1, 0.1, 9.0, true, false)  # Seen again: the clock starts over.
	for i in steps - 1:
		stats.step(1, 0.5, 9.0, false, false)
	assert_eq(stats.escape_count, 0)
	stats.step(1, 0.5, 9.0, false, false)
	assert_eq(stats.escape_count, 1)
	assert_false(stats.is_chased(1))


func test_seen_but_too_far_counts_as_out_of_sight() -> void:
	var stats := _stats()
	stats.step(1, 0.1, 5.0, true, false)
	for i in int(SETTINGS.escape_time / 0.5):
		stats.step(1, 0.5, SETTINGS.lost_range + 1.0, true, false)
	assert_eq(stats.escape_count, 1)


func test_a_capture_loses_the_chase() -> void:
	var stats := _stats()
	stats.step(1, 0.1, 5.0, true, false)
	stats.step(1, 0.1, 1.0, true, true)
	assert_eq(stats.catch_count, 1)
	assert_eq(stats.escape_count, 0)
	stats.step(1, 0.1, 5.0, true, false)  # Freed by a teammate, seen again.
	assert_eq(stats.chase_count, 2)


func test_a_hunted_out_for_good_is_never_chased_again() -> void:
	var stats := _stats()
	stats.step(1, 0.1, 5.0, true, false)
	stats.leave(1)
	assert_eq(stats.catch_count, 1)
	stats.step(1, 0.1, 5.0, true, false)
	assert_eq(stats.chase_count, 1)


func test_the_end_of_the_game_ends_the_chases() -> void:
	var won := _stats()
	won.step(1, 0.1, 5.0, true, false)
	won.step(2, 0.1, 5.0, true, false)
	won.finish(true)
	assert_eq(won.escape_count, 2, "the hunted got out")
	var lost := _stats()
	lost.step(1, 0.1, 5.0, true, false)
	lost.finish(false)
	assert_eq(lost.catch_count, 1, "the monster won")


func test_mean_distance_over_the_time_of_the_chases() -> void:
	var stats := _stats()
	assert_eq(stats.mean_distance(), 0.0)
	stats.step(1, 0.1, 9.0, true, false)  # Starts: not counted yet.
	stats.step(1, 1.0, 4.0, true, false)
	stats.step(1, 3.0, 8.0, true, false)
	stats.step(2, 0.1, 30.0, false, false)  # Not chased: not counted.
	assert_almost_eq(stats.mean_distance(), 7.0, 0.001)


func test_the_client_copies_the_room_figures() -> void:
	var room := _stats()
	room.step(1, 0.1, 5.0, true, false)
	room.step(1, 2.0, 6.0, true, false)
	room.finish(true)
	var client := _stats()
	client.apply(room.values())
	assert_eq(client.values(), room.values())


func test_the_monster_sees_in_front_with_nothing_in_between() -> void:
	var monster := Body.new()
	var hunted := Body.new()
	add_child_autofree(monster)
	add_child_autofree(hunted)
	hunted.position = Vector3(0, 0, -8)  # The monster faces -z.
	await wait_physics_frames(2)
	assert_true(ChaseWatch.sees(monster, hunted, SETTINGS))
	monster.rotation.y = PI  # Its back turned.
	await wait_physics_frames(1)
	assert_false(ChaseWatch.sees(monster, hunted, SETTINGS), "behind it")
	monster.rotation.y = 0.0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 4, 0.2)
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -4)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	assert_false(ChaseWatch.sees(monster, hunted, SETTINGS), "a wall in between")
