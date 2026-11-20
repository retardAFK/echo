extends GutTest
## The monster's rise (spec S-023, Q5 to Q7, T-354): one stage per objective
## done, read from game/data/escalation/, given to every monster of the game.

const MONSTER_SETTINGS := preload("res://game/data/monster_settings.tres")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const BUILDING_SCENE := preload("res://game/entities/building/building.tscn")
const MONSTER_SCENE := preload("res://game/entities/monster/monster.tscn")


func test_the_stages_follow_the_spec() -> void:
	var settings: MonsterSettings = MONSTER_SETTINGS.duplicate()
	var list := EscalationList.default()
	assert_eq(list.stages.size(), 3)
	list.apply(settings, 0, 1)
	assert_eq(settings.scan_recharge_time, 35.0, "stage 1: the scan recharges faster")
	assert_eq(settings.sprint_time, 5.0)
	list.apply(settings, 1, 2)
	assert_eq(settings.sprint_time, 6.5, "stage 2: it runs longer")
	assert_eq(settings.scan_recharge_time, 35.0, "stages add up")
	assert_false(settings.scan_whole_complex)
	list.apply(settings, 2, 9)
	assert_true(settings.scan_whole_complex, "stage 3: the scan hears every level")
	assert_eq(MONSTER_SETTINGS.scan_recharge_time, 45.0, "the game's settings never change")


func test_every_stage_names_real_settings_and_a_text() -> void:
	var names := {}
	for property in MONSTER_SETTINGS.get_property_list():
		names[property["name"]] = typeof(MONSTER_SETTINGS.get(property["name"]))
	for stage in EscalationList.default().stages:
		assert_ne(Text.t(stage.name_key), stage.name_key, "%s: a text" % stage.resource_path)
		assert_false(stage.overrides.is_empty(), "%s changes something" % stage.resource_path)
		for property: String in stage.overrides:
			assert_true(names.has(property), "%s is a MonsterSettings value" % property)
			assert_eq(
				typeof(stage.overrides[property]), names.get(property), property + ": its type"
			)


func test_objectives_done_count_fuses_and_the_others() -> void:
	var rules := LoopRules.new(3)
	assert_eq(rules.done_count(), 0)
	rules.take_fuse()
	rules.take_fuse()
	assert_eq(rules.done_count(), 0, "a fuse found is not done")
	rules.place_fuse()
	assert_eq(rules.done_count(), 1)
	rules.set_objectives([LoopRules.Objective.FUSE, LoopRules.Objective.CODE])
	rules.placed = 0
	rules.complete(LoopRules.Objective.CODE)
	assert_eq(rules.done_count(), 1, "the code")
	rules.placed = 1
	assert_eq(rules.done_count(), 2)


func _loop() -> GameLoop:
	var loop := GameLoop.new()
	loop.settings = LOOP_SETTINGS
	loop.mirror = true  # As on a client: no chase watch to feed, the rise all the same.
	var hunted := Node3D.new()
	add_child_autofree(hunted)
	loop.hunted = hunted
	add_child_autofree(loop)
	return loop


func test_each_objective_raises_every_monster_of_the_game() -> void:
	var monster: Monster = MONSTER_SCENE.instantiate()
	add_child_autofree(monster)
	assert_ne(monster.settings, MONSTER_SETTINGS, "its own copy")
	var loop := _loop()
	watch_signals(loop)
	loop.rules.take_fuse()
	loop.place_fuse()
	assert_signal_emitted_with_parameters(loop, "escalated", [1])
	assert_eq(monster.settings.scan_recharge_time, 35.0)
	assert_eq(MONSTER_SETTINGS.scan_recharge_time, 45.0)
	loop.rules.take_fuse()
	loop.place_fuse()
	assert_eq(monster.settings.sprint_time, 6.5)
	var late: Monster = MONSTER_SCENE.instantiate()  # An AI taking a player's place.
	add_child_autofree(late)
	await wait_physics_frames(2)
	assert_eq(late.settings.sprint_time, 6.5, "it gets the stages already reached")
	assert_eq(late.settings.scan_recharge_time, 35.0)
	loop.rules.take_fuse()
	loop.place_fuse()
	assert_signal_emit_count(loop, "escalated", 2 + 1)
	assert_true(monster.settings.scan_whole_complex)


func _level(complex: String, at: Vector3) -> Building:
	var building: Building = BUILDING_SCENE.instantiate()
	building.complex = complex
	var box := BoxShape3D.new()
	box.size = Vector3(10, 3, 10)
	(building.get_node("CollisionShape3D") as CollisionShape3D).shape = box
	add_child_autofree(building)
	building.global_position = at
	return building


func test_at_the_last_stage_the_scan_hears_every_level() -> void:
	var ground := _level("hospital", Vector3.ZERO)
	var upstairs := _level("hospital", Vector3(0, 3.5, 0))
	var other := _level("", Vector3(30, 0, 0))
	var settings: MonsterSettings = MONSTER_SETTINGS.duplicate()
	assert_true(ScanGauge.holds(ground, Vector3.ZERO, settings))
	assert_false(ScanGauge.holds(ground, upstairs.global_position, settings), "one level (S-014)")
	settings.scan_whole_complex = true
	assert_true(ScanGauge.holds(ground, upstairs.global_position, settings))
	assert_false(ScanGauge.holds(ground, other.global_position, settings), "not another building")
	assert_false(ScanGauge.holds(other, Vector3.ZERO, settings), "a building of one level")


func test_the_hunted_hear_the_growl_and_read_the_line() -> void:
	var loop := _loop()
	var hud: LoopHud = preload("res://game/ui/loop_hud.tscn").instantiate()
	hud.game_loop = loop
	add_child_autofree(hud)
	var rise := hud.get_node("Rise") as Label
	assert_false(rise.visible)
	loop.rules.take_fuse()
	loop.place_fuse()
	assert_true(rise.visible)
	assert_eq(rise.text, "Le monstre s'énerve")
	assert_eq(
		(hud.get_node("Rumble") as AudioStreamPlayer).stream.resource_path.get_file(),
		"monster_rumble.wav"
	)
	hud._process(LOOP_SETTINGS.rise_message_time + 0.1)
	assert_false(rise.visible, "for a moment only")
