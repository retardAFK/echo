extends GutTest
## Fuses of the game loop: holding, drawing, boxes and HUD (spec S-007, T-054).

const BOX_SCENE := preload("res://game/entities/fuse_box/fuse_box.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const PROMPT_SCENE := preload("res://game/ui/interact_prompt.tscn")
const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")

var _fuse_noises: Array[NoiseEvent] = []


func before_each() -> void:
	_fuse_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.FUSE:
		_fuse_noises.append(event)


func _make_box(with_fuse := true) -> FuseBox:
	var box: FuseBox = BOX_SCENE.instantiate()
	add_child_autofree(box)
	box.set_fuse(with_fuse)
	return box


func test_settings_follow_the_spec() -> void:
	var settings: LoopSettings = load("res://game/data/loop_settings.tres")
	assert_eq(settings.fuse_count, 3, "Q1")
	assert_eq(settings.pickup_time, 2.0, "Q2: 2 s")
	assert_eq(settings.fuse_noise_range, 3.0, "Q2: 3 m")
	assert_eq(settings.repair_time, 4.0, "Q3: 4 s per fuse")
	assert_eq(settings.repair_noise_range, 8.0, "Q3: 8 m")
	assert_eq(settings.kept_on_release, 0.5, "Q3: half kept")
	assert_eq(settings.siren_time, 10.0, "Q4: 10 s")


func test_hold_progress_fills_and_keeps_a_share_when_let_go() -> void:
	var start_over := HoldProgress.new(2.0)
	assert_false(start_over.advance(1.5))
	assert_almost_eq(start_over.get_ratio(), 0.75, 0.001)
	start_over.release()
	assert_eq(start_over.get_ratio(), 0.0, "a fuse box starts over")
	var keep_half := HoldProgress.new(4.0, 0.5)
	keep_half.advance(3.0)
	keep_half.release()
	assert_almost_eq(keep_half.done, 1.5, 0.001, "the transformer keeps half")
	assert_false(keep_half.advance(2.0))
	assert_true(keep_half.advance(0.6), "finishes from what was kept")
	assert_eq(keep_half.done, 0.0, "ready for the next one")


func test_fuses_go_to_different_buildings_and_change_between_games() -> void:
	var by_building := {}
	for building_name in ["Tower", "SocialCentre", "Gallery", "CarPark"]:
		by_building[building_name] = []
		for i in 4:
			by_building[building_name].append("%s%d" % [building_name, i])
	var draws := {}
	for game in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = game + 1
		var chosen := LoopRules.draw_fuses(by_building, 3, rng)
		assert_eq(chosen.size(), 3)
		var buildings := {}
		for box: String in chosen:
			buildings[box.left(box.length() - 1)] = true
		assert_eq(buildings.size(), 3, "three different buildings")
		draws[str(chosen)] = true
	assert_gt(draws.size(), 10, "the fuses move from one game to the next")


func test_rules_count_found_and_placed_fuses() -> void:
	var rules := LoopRules.new(3)
	assert_false(rules.place_fuse(), "nothing to place")
	rules.take_fuse()
	rules.take_fuse()
	assert_eq(rules.found(), 2)
	assert_true(rules.place_fuse())
	assert_eq([rules.carried, rules.placed, rules.found(), rules.missing()], [1, 1, 2, 2])
	rules.take_fuse()
	rules.place_fuse()
	rules.place_fuse()
	assert_true(rules.is_repaired())


func test_holding_takes_the_fuse_with_a_metal_noise() -> void:
	var box := _make_box()
	var user := Node.new()
	add_child_autofree(user)
	watch_signals(box)
	assert_true(box.get_node("Led").visible, "a full box shows its LED")
	assert_true(box.can_interact(box.global_position + Vector3(0, 0, 1.5)))
	box.hold(user, 0.5)
	assert_eq(_fuse_noises.size(), 1, "the metal clanks when the hunted starts")
	assert_eq(_fuse_noises[0].noise_range, 3.0)
	assert_eq(_fuse_noises[0].source, user, "heard as the hunted's noise")
	for i in 3:
		box.hold(user, 0.5)
	assert_false(box.has_fuse)
	assert_signal_emitted_with_parameters(box, "fuse_taken", [user])
	assert_eq(_fuse_noises.size(), 2, "and when the fuse comes out")
	assert_false(box.get_node("Led").visible)
	assert_false(box.can_interact(box.global_position), "an empty box offers nothing")
	assert_eq(box.get_prompt(), "")


func test_letting_go_of_a_box_starts_over() -> void:
	var box := _make_box()
	var hold := HoldInteraction.new()
	var user := Node.new()
	add_child_autofree(user)
	hold.update(user, box, true, 1.5)
	assert_almost_eq(hold.get_ratio(), 0.75, 0.001)
	hold.update(user, box, false, 0.1)
	assert_eq(box.get_hold_ratio(), 0.0)
	hold.update(user, box, true, 1.5)
	hold.update(user, null, true, 0.1)  # Out of reach or aim turned away.
	assert_eq(box.get_hold_ratio(), 0.0)
	assert_true(box.has_fuse)


func test_a_key_still_held_from_getting_up_holds_nothing() -> void:
	var box := _make_box()
	var hold := HoldInteraction.new()
	var user := Node.new()
	add_child_autofree(user)
	hold.wait_release()  # "interact" just got it up from a terminal (S-018).
	hold.update(user, box, true, 1.5)
	assert_eq(box.get_hold_ratio(), 0.0, "not until the key is let go")
	hold.update(user, box, false, 0.1)
	hold.update(user, box, true, 1.5)
	assert_almost_eq(hold.get_ratio(), 0.75, 0.001, "then it holds again")


func test_player_holds_e_on_a_box_and_sees_the_ring() -> void:
	var box := _make_box()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child_autofree(floor_body)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = box.global_position + Vector3(0, 0, 1.2)  # Facing -Z: the box.
	var prompt: InteractPrompt = PROMPT_SCENE.instantiate()
	prompt.player = player
	add_child_autofree(prompt)
	await wait_physics_frames(2)
	await wait_process_frames(2)
	assert_eq(player.get_interactable(), box)
	assert_eq(prompt.get_node("Label").text, Settings.fill(tr("HUD_INTERACT_FUSE_BOX")))
	Input.action_press("interact")
	await wait_seconds(1.0)
	assert_between(player.get_hold_ratio(), 0.3, 0.7)
	assert_gt(prompt.get_node("HoldRing").ratio, 0.0, "the ring fills")
	await wait_seconds(1.3)
	Input.action_release("interact")
	assert_false(box.has_fuse)


func test_the_cite_draws_three_fuses_in_three_buildings() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var boxes := map.get_fuse_boxes()
	assert_eq(boxes.size(), 24, "a box on each fuse slot")
	assert_not_null(map.game_loop)
	var full := boxes.filter(func(box: FuseBox) -> bool: return box.has_fuse)
	assert_eq(full.size(), 3)
	var buildings := {}
	for box: FuseBox in full:
		buildings[box.building_name] = true
		assert_true(box.get_node("Led").visible)
	assert_eq(buildings.size(), 3, "three different buildings")
	for box: FuseBox in boxes:
		assert_eq(box.get_node("Led").visible, box.has_fuse, "no LED on an empty box")
	var is_hud := func(node: Node) -> bool: return node is LoopHud
	var hud: LoopHud = map.get_children().filter(is_hud)[0]
	assert_string_contains(hud.get_node("Label").text, "0/3")
	full[0].hold(map.get_node("Player"), 2.1)
	assert_eq(map.game_loop.rules.found(), 1)
	assert_string_contains(hud.get_node("Label").text, "1/3")


func test_fuse_boxes_hang_on_a_wall_facing_the_room() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(2)
	var space := map.get_world_3d().direct_space_state
	for box: FuseBox in map.get_fuse_boxes():
		var at := box.global_position + Vector3.UP * 1.3 + box.global_basis.z * 0.3
		var behind := PhysicsRayQueryParameters3D.create(at, at - box.global_basis.z * 0.6, 2)
		assert_false(space.intersect_ray(behind).is_empty(), "wall behind %s" % box.get_path())
		var front := box.get_approach_point()
		var slot: Node3D = box.get_parent()
		assert_lt(
			Vector2(front.x - slot.global_position.x, front.z - slot.global_position.z).length(),
			3.5
		)
