extends GutTest
## The gusts of the cité (spec S-012, T-144, Q8).

const BUILDING_SCENE := preload("res://game/entities/building/building.tscn")

var _audio := AudioSettings.new()


func after_each() -> void:
	NoiseBus.wind_gust = false


func test_gusts_come_now_and_then_and_build_up() -> void:
	var gusts := WindGusts.new(42, _audio)
	assert_eq(gusts.strength(0.0), 0.0, "calm at the start")
	var first := 0.0
	var count := 0
	var was := false
	for i in 6000:  # Ten minutes, a tenth of a second at a time.
		var t := i * 0.1
		var now := gusts.is_gusting(t)
		if now and not was:
			count += 1
			if first == 0.0:
				first = t
		was = now
	assert_between(first, _audio.gust_interval.x, _audio.gust_interval.y + _audio.gust_rise + 0.2)
	var low := 600.0 / (_audio.gust_interval.y + _audio.gust_length.y)
	var high := 600.0 / (_audio.gust_interval.x + _audio.gust_length.x) + 1.0
	assert_between(float(count), floorf(low), ceilf(high))
	var gust: Vector2 = gusts.gusts[0]
	var half_up := gusts.strength(gust.x - _audio.gust_rise / 2.0)
	assert_almost_eq(half_up, 0.5, 0.01, "it rises before")
	assert_false(gusts.is_gusting(gust.x - 0.1), "not yet at full strength")
	assert_true(gusts.is_gusting((gust.x + gust.y) / 2.0))


func test_the_same_seed_blows_the_same_gusts() -> void:
	var a := WindGusts.new(7, _audio)
	var b := WindGusts.new(7, _audio)
	for t: float in [10.0, 33.3, 61.0, 120.5, 300.0]:
		assert_eq(a.strength(t), b.strength(t))


func test_a_gust_cuts_small_noises_outdoors_only() -> void:
	var building: Building = BUILDING_SCENE.instantiate()
	building.size = Vector3(10, 4, 10)
	add_child_autofree(building)
	building.global_position = Vector3(0, 2, 0)
	var noise := NoiseBus.settings
	var outside := Vector3(30, 0.3, 0)
	var inside := Vector3(0, 0.3, 0)
	assert_eq(NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, outside, 4.0).noise_range, 4.0, "calm")
	NoiseBus.wind_gust = true
	var walk := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, outside, noise.walk_range)
	assert_eq(walk.noise_range, noise.walk_range * noise.wind_factor, "walking: 4 -> 2 m")
	var metal := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, outside, noise.metal_walk_range)
	assert_eq(metal.noise_range, 3.0, "metal walk: 6 -> 3 m")
	var run := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, outside, noise.sprint_range)
	assert_eq(run.noise_range, noise.sprint_range, "running is still heard")
	var indoors := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, inside, noise.walk_range)
	assert_eq(indoors.noise_range, noise.walk_range, "indoors, no wind")


func test_the_wind_follows_its_gusts_and_stops_when_gone() -> void:
	var wind := CityWind.new()
	wind.gust_seed = 5
	add_child(wind)
	wind.gusts.strength(100.0)
	var gust: Vector2 = wind.gusts.gusts[0]
	wind.time = (gust.x + gust.y) / 2.0 - 0.01
	wind._process(0.01)
	assert_true(NoiseBus.wind_gust)
	assert_gt(wind.volume_db, -1.0, "louder in a gust")
	wind.queue_free()
	await wait_process_frames(2)
	assert_false(NoiseBus.wind_gust, "no gust left behind")


func test_online_the_client_blows_the_room_s_gusts() -> void:
	var wind := CityWind.new()
	add_child_autofree(wind)
	var other := CityWind.new()
	add_child_autofree(other)
	wind.gusts.strength(60.0)  # Draws the first gusts.
	var gust: Vector2 = wind.gusts.gusts[0]
	var middle := (gust.x + gust.y) / 2.0
	other.sync(wind.seed_used, middle)
	assert_eq(other.seed_used, wind.seed_used)
	assert_eq(other.strength, 1.0, "in the room's gust")
	other._process(0.01)
	assert_true(NoiseBus.wind_gust)
	assert_almost_eq(other.time, middle + 0.01, 0.0001, "then on its own clock")
