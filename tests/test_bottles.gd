extends GutTest
## Bottles to pick up and throw (spec S-008, T-063).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const PICKUP_SCENE := preload("res://game/entities/pickup/bottle_pickup.tscn")
const PROMPT_SCENE := preload("res://game/ui/interact_prompt.tscn")
const HUD_SCENE := preload("res://game/ui/carry_hud.tscn")
const SETTINGS := preload("res://game/data/ruse_settings.tres")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _of_type(type: NoiseEvent.Type) -> Array[NoiseEvent]:
	var found: Array[NoiseEvent] = []
	for event in _noises:
		if event.type == type:
			found.append(event)
	return found


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


func _add_wall(z: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 6, 0.3)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0, 3, z)


func _make_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.max_bottles, 2, "Q1: 2 bottles at most")
	assert_eq(SETTINGS.max_decoys, 1, "Q3: 1 alarm clock at most")
	assert_eq(SETTINGS.impact_range, 8.0, "Q2 and section 6.2: impact, 8 m")
	assert_eq(SETTINGS.gesture_range, 1.0, "Q2: the gesture, 1 m")


func test_inventory_caps_and_uses() -> void:
	var inventory := Inventory.new(SETTINGS)
	watch_signals(inventory)
	assert_true(inventory.take(Inventory.Kind.BOTTLE))
	assert_true(inventory.take(Inventory.Kind.BOTTLE))
	assert_false(inventory.take(Inventory.Kind.BOTTLE), "no third bottle")
	assert_eq(inventory.count(Inventory.Kind.BOTTLE), 2)
	assert_true(inventory.take(Inventory.Kind.DECOY))
	assert_false(inventory.can_take(Inventory.Kind.DECOY))
	assert_true(inventory.use(Inventory.Kind.BOTTLE))
	assert_eq(inventory.count(Inventory.Kind.BOTTLE), 1)
	assert_true(inventory.use(Inventory.Kind.DECOY))
	assert_false(inventory.use(Inventory.Kind.DECOY), "nothing left to use")
	assert_signal_emit_count(inventory, "changed", 5)


func test_a_throw_lands_about_fifteen_meters_away() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var reach := ThrownBottle.flat_range(SETTINGS.throw_speed, SETTINGS.throw_lift, 1.6, gravity)
	assert_between(reach, 14.0, 16.5, "Q2: about 15 m on flat ground")


func test_player_picks_up_bottles_in_front_until_full() -> void:
	_add_floor()
	var player := _make_player()
	var bottles: Array[Pickup] = []
	for i in 3:
		var bottle: Pickup = PICKUP_SCENE.instantiate()
		add_child_autofree(bottle)
		bottle.global_position = Vector3(0.2 * i, 0, -1.0)  # In front: the player faces -Z.
		bottles.append(bottle)
	var prompt: InteractPrompt = PROMPT_SCENE.instantiate()
	prompt.player = player
	add_child_autofree(prompt)
	await wait_physics_frames(2)
	await wait_process_frames(2)
	assert_eq(prompt.get_node("Label").text, "HUD_INTERACT_PICKUP_BOTTLE")
	player.interact()
	await wait_process_frames(2)
	player.interact()
	await wait_process_frames(2)
	assert_eq(player.inventory.count(Inventory.Kind.BOTTLE), 2)
	var left := 0
	for bottle in bottles:
		if is_instance_valid(bottle) and not bottle.is_queued_for_deletion():
			left += 1
	assert_eq(left, 1, "two bottles taken")
	assert_null(player.get_interactable(), "no room left: the third one is not offered")
	assert_eq(_noises.size(), 0, "picking up is silent (Q1)")


func test_carry_hud_shows_what_is_carried() -> void:
	var player := _make_player()
	var hud: CarryHud = HUD_SCENE.instantiate()
	hud.player = player
	add_child_autofree(hud)
	var label: Label = hud.get_node("Label")
	assert_eq(label.text, "")
	player.inventory.take(Inventory.Kind.BOTTLE)
	assert_eq(label.text, tr("HUD_CARRY_BOTTLE"))
	player.inventory.take(Inventory.Kind.BOTTLE)
	assert_eq(label.text, tr("HUD_CARRY_BOTTLES") % 2)


func test_no_bottle_no_throw() -> void:
	var player := _make_player()
	assert_null(player.throw_bottle())
	assert_eq(_noises.size(), 0)


func test_a_thrown_bottle_breaks_on_the_ground_far_away() -> void:
	_add_floor()
	var player := _make_player()
	await wait_physics_frames(2)
	player.inventory.take(Inventory.Kind.BOTTLE)
	var bottle := player.throw_bottle()
	assert_not_null(bottle)
	assert_eq(player.inventory.count(Inventory.Kind.BOTTLE), 0)
	var throws := _of_type(NoiseEvent.Type.THROW)
	assert_eq(throws.size(), 1, "the gesture makes a faint noise")
	assert_eq(throws[0].noise_range, SETTINGS.gesture_range)
	await wait_seconds(2.0)
	var impacts := _of_type(NoiseEvent.Type.IMPACT)
	assert_eq(impacts.size(), 1, "one impact")
	if impacts.is_empty():
		return
	assert_eq(impacts[0].noise_range, SETTINGS.impact_range)
	var flat := Vector2(impacts[0].position.x, impacts[0].position.z).length()
	assert_between(flat, 11.0, 17.0, "lands about 15 m away, straight ahead")
	assert_lt(impacts[0].position.z, 0.0, "in front of the player")
	assert_false(is_instance_valid(bottle), "the bottle is gone")


func test_a_bottle_breaks_against_a_wall() -> void:
	_add_floor()
	_add_wall(-5.0)
	var player := _make_player()
	await wait_physics_frames(2)
	player.inventory.take(Inventory.Kind.BOTTLE)
	player.throw_bottle()
	await wait_seconds(1.0)
	var impacts := _of_type(NoiseEvent.Type.IMPACT)
	assert_eq(impacts.size(), 1)
	if impacts.is_empty():
		return
	assert_between(impacts[0].position.z, -5.0, -4.5, "breaks on the wall, not through it")


func test_a_bottle_that_touches_nothing_breaks_in_the_end() -> void:
	var bottle: ThrownBottle = load("res://game/entities/bottle/thrown_bottle.tscn").instantiate()
	var settings: RuseSettings = SETTINGS.duplicate()
	settings.bottle_max_flight = 0.3
	bottle.settings = settings
	bottle.gravity_scale = 0.0
	add_child_autofree(bottle)
	await wait_seconds(0.5)
	assert_eq(_of_type(NoiseEvent.Type.IMPACT).size(), 1)


func test_the_monster_goes_to_check_an_impact() -> void:
	var brain := MonsterBrain.new(load("res://game/data/monster_settings.tres"))
	var spot := Vector3(12, 0, -3)
	brain.hear(spot)
	assert_eq(brain.state, MonsterBrain.State.INVESTIGATE)
	assert_eq(brain.target, spot)
