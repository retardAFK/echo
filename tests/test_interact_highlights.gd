extends GutTest
## Marks on what the hunted can use nearby (S-009, T-087).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _map: GameMap
var _player: Player
var _highlights: InteractHighlights
var _pickup: Pickup


func before_each() -> void:
	GameSession.role = GameSession.Role.HUNTED
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_player = _map.get_node("Player")
	_player.set_physics_process(false)
	_highlights = _map.find_children("*", "InteractHighlights", false, false)[0]
	_highlights.set_process(false)  # Driven by hand.
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if node is Pickup:
			_pickup = node
			break
	await wait_physics_frames(2)


func _stand(distance: float) -> void:
	var target := _pickup.global_position
	_player.global_position = target + Vector3(distance, 0.1, 0)
	_player.look_at(Vector3(target.x, _player.global_position.y, target.z), Vector3.UP)
	await wait_physics_frames(2)


func _marks() -> int:
	_highlights.marks.clear()
	_highlights.update_marks(_player.get_viewport().get_camera_3d())
	return _highlights.marks.size()


func test_pickup_in_range_is_marked() -> void:
	assert_not_null(_pickup, "the greybox has pickups")
	await _stand(3.0)
	assert_gt(_marks(), 0)


func test_out_of_range_is_not_marked() -> void:
	await _stand(_player.settings.highlight_range + 20.0)
	var camera := _player.get_viewport().get_camera_3d()
	_highlights.marks.clear()
	_highlights.update_marks(camera)
	for mark in _highlights.marks:
		assert_ne(mark, camera.unproject_position(InteractHighlights.mark_position(_pickup)))


func test_pickup_marked_above_itself() -> void:
	var point := InteractHighlights.mark_position(_pickup)
	assert_gt(point.y, _pickup.global_position.y)


func test_useful_follows_the_prompt() -> void:
	assert_true(InteractHighlights.is_useful(_pickup, _player))
	var spot: HidingSpot = _map.get_node("Closet")
	assert_true(InteractHighlights.is_useful(spot, _player), "a free closet")
	spot.occupant = Node3D.new()
	assert_false(InteractHighlights.is_useful(spot, _player), "someone else is inside")
	spot.occupant.free()
	spot.occupant = null
