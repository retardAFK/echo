extends GutTest
## Hiding spots: closets and dumpsters (spec S-008, T-065).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const CLOSET_SCENE := preload("res://game/entities/hiding_spot/closet.tscn")
const DUMPSTER_SCENE := preload("res://game/entities/hiding_spot/dumpster.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MASK_SCENE := preload("res://game/ui/hide_mask.tscn")
const SETTINGS := preload("res://game/data/ruse_settings.tres")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _count(type: NoiseEvent.Type, source: Object = null) -> int:
	var count := 0
	for event in _noises:
		if event.type == type and (source == null or event.source == source):
			count += 1
	return count


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


## A closet 2 m in front of a player at the origin, its door facing them.
func _setup() -> Array:
	_add_floor()
	var closet: HidingSpot = CLOSET_SCENE.instantiate()
	add_child_autofree(closet)
	closet.global_position = Vector3(0, 0, -2)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(3)
	return [closet, player]


func _hide(closet: HidingSpot, player: Player) -> void:
	closet.hold(player, 0.6)
	closet.hold(player, 0.6)
	closet.release(player)


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.hide_time, 1.0, "Q5: 1 s to get in or out")
	assert_eq(SETTINGS.hide_noise_range, 3.0, "Q5: a noise of 3 m")


func test_player_hides_in_a_closet_with_a_creak() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	assert_eq(player.get_interactable(), closet)
	assert_eq(closet.get_prompt_for(player), "HUD_INTERACT_HIDE")
	closet.hold(player, 0.5)
	assert_false(player.is_hidden(), "half way")
	assert_almost_eq(closet.get_hold_ratio(), 0.5, 0.01)
	closet.hold(player, 0.6)
	assert_true(player.is_hidden())
	assert_eq(closet.occupant, player)
	assert_eq(_count(NoiseEvent.Type.HIDE), 1)
	assert_almost_eq(player.global_position.z, -2.0, 0.01, "inside the closet")
	assert_eq(player.get_interactable(), closet, "the only thing in reach: the way out")
	assert_eq(closet.get_prompt_for(player), "HUD_INTERACT_LEAVE")


func test_holding_on_does_not_get_straight_back_out() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	closet.hold(player, 1.1)
	closet.hold(player, 2.0)
	assert_true(player.is_hidden(), "still inside until E is released")
	closet.release(player)
	closet.hold(player, 1.1)
	assert_false(player.is_hidden())
	assert_null(closet.occupant)
	assert_eq(_count(NoiseEvent.Type.HIDE), 2, "a creak in, a creak out")
	assert_almost_eq(player.global_position.z, closet.get_exit_point().z, 0.01, "out in front")


func test_hidden_player_stays_put_silent_and_cannot_use_ruses() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	_hide(closet, player)
	player.inventory.take(Inventory.Kind.BOTTLE)
	player.inventory.take(Inventory.Kind.DECOY)
	Input.action_press("move_forward")
	await wait_physics_frames(30)
	Input.action_release("move_forward")
	assert_almost_eq(player.global_position.z, -2.0, 0.01, "does not move")
	assert_eq(_count(NoiseEvent.Type.FOOTSTEP, player), 0, "no footstep, not even getting in")
	assert_null(player.throw_bottle())
	assert_null(player.place_decoy())
	assert_eq(player.inventory.count(Inventory.Kind.BOTTLE), 1)


func test_hidden_head_turns_only_a_little() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	_hide(closet, player)
	var out := closet.get_out_yaw()
	player.look(Vector2(400, 400))  # 60° each way: past both limits.
	var turned := absf(angle_difference(out, player.rotation.y))
	assert_almost_eq(turned, deg_to_rad(SETTINGS.hidden_yaw_limit), 0.01)
	assert_almost_eq(absf(player.get_pitch()), deg_to_rad(SETTINGS.hidden_pitch_limit), 0.01)


func test_a_breathless_player_still_pants_inside() -> void:
	# D-009 and Q6: the scan hears the breath of a hunted who ran just before.
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	_hide(closet, player)
	assert_false(player.is_breathless())
	player._breathless_left = 3.0
	await wait_seconds(1.5)
	assert_gt(_count(NoiseEvent.Type.BREATH, player), 0)
	for event in _noises:
		if event.type == NoiseEvent.Type.BREATH:
			assert_eq(event.noise_range, player.settings.breath_range)


func test_a_dumpster_hides_crouched() -> void:
	_add_floor()
	var dumpster: HidingSpot = DUMPSTER_SCENE.instantiate()
	add_child_autofree(dumpster)
	dumpster.global_position = Vector3(0, 0, -2)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(3)
	_hide(dumpster, player)
	assert_true(player.is_hidden())
	assert_eq(player.get_gait(), PlayerMotion.Gait.CROUCH)


func test_one_hunted_per_spot() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	_hide(closet, player)
	var other: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(other)
	assert_false(closet.wanted_by(other))
	assert_eq(closet.get_prompt_for(other), "")


func test_the_monster_opens_it_and_catches_who_hides_there() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	_hide(closet, player)
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.global_position = Vector3(0, 0, 0)
	await wait_physics_frames(2)
	assert_eq(avatar.get_interactable(), closet)
	assert_eq(closet.get_prompt_for(avatar), "HUD_INTERACT_OPEN")
	watch_signals(closet)
	closet.hold(avatar, 1.1)
	assert_signal_emitted_with_parameters(closet, "found", [player, avatar])
	assert_false(player.is_hidden())
	assert_eq(_count(NoiseEvent.Type.HIDE, closet), 2, "in, then opened")


func test_the_monster_opens_an_empty_one_for_nothing() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	watch_signals(closet)
	closet.hold(avatar, 1.1)
	assert_signal_emitted(closet, "opened")
	assert_signal_not_emitted(closet, "found")


func test_searching_an_empty_one_costs_the_monster() -> void:
	# S-020, T-310 (piste H1): a 4 m noise and a second standing there.
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	closet.hold(avatar, 1.1)
	var opened := _noises.filter(func(e: NoiseEvent) -> bool: return e.source == closet)
	assert_eq(opened.size(), 1)
	assert_eq(opened[0].noise_range, SETTINGS.empty_search_range, "louder than the 3 m creak")
	assert_eq(avatar.stagger.left, SETTINGS.empty_search_stagger, "it stands there")
	assert_eq(avatar.stagger.count, 1)


func test_finding_someone_costs_the_monster_nothing() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	_hide(closet, setup[1])
	_noises.clear()
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	closet.hold(avatar, 1.1)
	assert_eq(_noises[0].noise_range, SETTINGS.hide_noise_range)
	assert_eq(avatar.stagger.left, 0.0)


func test_the_mask_shows_only_when_hidden() -> void:
	var setup: Array = await _setup()
	var closet: HidingSpot = setup[0]
	var player: Player = setup[1]
	var mask: HideMask = MASK_SCENE.instantiate()
	mask.player = player
	add_child_autofree(mask)
	await wait_process_frames(2)
	assert_false(mask.visible)
	_hide(closet, player)
	await wait_process_frames(2)
	assert_true(mask.visible)
	var height := mask.get_viewport().get_visible_rect().size.y
	var top: ColorRect = mask.get_node("Top")
	assert_almost_eq(top.size.y, height * (1.0 - SETTINGS.slit_share) / 2.0, 1.0)
