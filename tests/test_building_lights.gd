extends GutTest
## Lights that flicker in a scanned building (spec S-004, D-009, T-024).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _map: Node3D
var _building: Building


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_building = _map.get_node("Building")


func _energies() -> Array[float]:
	var energies: Array[float] = []
	for light in _building.get_lights():
		energies.append(light.light_energy)
	return energies


func test_one_light_per_room() -> void:
	assert_eq(_building.get_lights().size(), 2)
	for light in _building.get_lights():
		assert_true(_building.contains(light.global_position))
		assert_false(light.shadow_enabled, "no shadows, for the web build")


func test_lights_flicker_while_scanned() -> void:
	var steady := _energies()
	_building.scanned = true
	var seen_dim := false
	for i in 20:
		await wait_physics_frames(3)
		for j in steady.size():
			var energy: float = _energies()[j]
			assert_between(
				energy, steady[j] * _building.settings.light_flicker_min - 0.001, steady[j] + 0.001
			)
			if energy < steady[j] * 0.95:
				seen_dim = true
	assert_true(seen_dim, "the lights dim at times")


func test_lights_come_back_when_the_scan_ends() -> void:
	var steady := _energies()
	_building.scanned = true
	await wait_physics_frames(20)
	_building.scanned = false
	assert_eq(_energies(), steady)


func test_no_message_on_screen() -> void:
	# The warning is only the lights: scanning shows nothing on the hunted's HUD.
	var labels_before := _map.find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return l.is_visible_in_tree()
	)
	_building.scanned = true
	await wait_physics_frames(5)
	var labels_after := _map.find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return l.is_visible_in_tree()
	)
	assert_eq(labels_after.size(), labels_before.size())
