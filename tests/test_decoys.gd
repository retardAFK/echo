extends GutTest
## Alarm clock decoys (spec S-008, T-064).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const PICKUP_SCENE := preload("res://game/entities/pickup/decoy_pickup.tscn")
const DECOY_SCENE := preload("res://game/entities/decoy/decoy.tscn")
const MONSTER_SETTINGS := preload("res://game/data/monster_settings.tres")
const SETTINGS := preload("res://game/data/ruse_settings.tres")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _rings() -> Array[NoiseEvent]:
	var found: Array[NoiseEvent] = []
	for event in _noises:
		if event.type == NoiseEvent.Type.DECOY:
			found.append(event)
	return found


func _fast_settings() -> RuseSettings:
	var settings: RuseSettings = SETTINGS.duplicate()
	settings.decoy_delay = 0.3
	settings.decoy_ring_time = 0.5
	settings.decoy_noise_interval = 0.2
	return settings


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.decoy_delay, 15.0, "Q3: rings 15 s later")
	assert_eq(SETTINGS.decoy_ring_time, 10.0, "Q3: for 10 s")
	assert_eq(SETTINGS.decoy_range, 12.0, "Q3: a noise of 12 m")
	assert_eq(SETTINGS.decoy_noise_interval, 1.0, "Q3: every second")


func test_timer_ticks_then_rings_then_stops() -> void:
	var timer := DecoyTimer.new(SETTINGS)
	var noises := 0
	var step := 0.05
	var elapsed := 0.0
	while elapsed < 14.9:
		if timer.update(step):
			noises += 1
		elapsed += step
	assert_eq(timer.state, DecoyTimer.State.TICKING, "silent for 15 s")
	assert_eq(noises, 0)
	while elapsed < 30.0:
		if timer.update(step):
			noises += 1
		elapsed += step
	assert_eq(timer.state, DecoyTimer.State.DONE)
	assert_between(noises, 10, 11, "one noise a second for 10 s")


func test_a_crushed_timer_stays_silent() -> void:
	var timer := DecoyTimer.new(SETTINGS)
	timer.update(15.0)
	assert_eq(timer.state, DecoyTimer.State.RINGING)
	assert_true(timer.crush())
	assert_false(timer.crush(), "already done")
	for i in 40:
		assert_false(timer.update(0.5))


func test_player_picks_up_one_alarm_clock_and_places_it() -> void:
	_add_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	add_child_autofree(pickup)
	pickup.global_position = Vector3(0, 0, -1)
	await wait_physics_frames(3)
	assert_eq(player.get_interactable(), pickup)
	assert_eq(pickup.get_prompt(), "HUD_INTERACT_PICKUP_DECOY")
	player.interact()
	assert_eq(player.inventory.count(Inventory.Kind.DECOY), 1)
	var decoy := player.place_decoy()
	assert_not_null(decoy)
	autofree(decoy)
	assert_eq(player.inventory.count(Inventory.Kind.DECOY), 0)
	assert_almost_eq(decoy.global_position.z, -SETTINGS.decoy_place_distance, 0.05, "in front")
	assert_almost_eq(decoy.global_position.y, 0.0, 0.05, "on the ground")
	assert_eq(_noises.size(), 1, "only the faint gesture: ticking is silent for the monster")
	assert_eq(_noises[0].noise_range, SETTINGS.gesture_range)
	assert_null(player.place_decoy(), "none left")


func test_a_placed_decoy_rings_where_it_lies() -> void:
	var decoy: Decoy = DECOY_SCENE.instantiate()
	decoy.settings = _fast_settings()
	add_child_autofree(decoy)
	decoy.global_position = Vector3(5, 0, 3)
	watch_signals(decoy)
	await wait_seconds(0.2)
	assert_eq(_rings().size(), 0)
	await wait_seconds(0.8)
	assert_signal_emitted(decoy, "ringing_started")
	assert_between(_rings().size(), 2, 4)
	assert_eq(_rings()[0].noise_range, decoy.settings.decoy_range)
	assert_almost_eq(_rings()[0].position.x, 5.0, 0.01)
	assert_false(decoy.is_ringing(), "done after its ring time")


func test_the_monster_crushes_a_ringing_decoy_it_reaches() -> void:
	var decoy: Decoy = DECOY_SCENE.instantiate()
	decoy.settings = _fast_settings()
	add_child_autofree(decoy)
	decoy.global_position = Vector3(5, 0, 3)
	var far := Vector3(5, 0, 3 + MONSTER_SETTINGS.catch_distance + 1.0)
	assert_eq(Decoy.crush_near(get_tree(), far, MONSTER_SETTINGS.catch_distance), 0)
	await wait_seconds(0.35)
	assert_true(decoy.is_ringing())
	var near := Vector3(5.2, 0, 3)
	assert_eq(Decoy.crush_near(get_tree(), near, MONSTER_SETTINGS.catch_distance), 1)
	assert_false(decoy.is_ringing())
	var count := _rings().size()
	await wait_seconds(0.5)
	assert_eq(_rings().size(), count, "silent once crushed")


func test_a_ticking_decoy_is_not_crushed() -> void:
	# Q4: the monster crushes it when it rings; a ticking one is not found yet.
	var decoy: Decoy = DECOY_SCENE.instantiate()
	add_child_autofree(decoy)
	assert_eq(Decoy.crush_near(get_tree(), decoy.global_position, 1.0), 0)
	assert_eq(decoy.timer.state, DecoyTimer.State.TICKING)
