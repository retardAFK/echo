class_name WindGusts
extends RefCounted
## When the gusts blow over the cité (spec S-012, T-144, Q8): drawn from a
## seed, so the same seed gives the same gusts. Pure, testable without a scene.

var audio: AudioSettings
## Each gust: [start of full strength, end of full strength], in seconds.
var gusts: Array[Vector2] = []

var _rng := RandomNumberGenerator.new()


func _init(p_seed: int, p_audio: AudioSettings) -> void:
	_rng.seed = p_seed
	audio = p_audio


## Wind strength at a time: 0 calm, 1 a full gust, rising and falling in
## between over gust_rise seconds.
func strength(time: float) -> float:
	_extend(time)
	var best := 0.0
	for gust in gusts:
		if time < gust.x - audio.gust_rise:
			break
		var rise := (time - (gust.x - audio.gust_rise)) / audio.gust_rise
		var fall := ((gust.y + audio.gust_rise) - time) / audio.gust_rise
		best = maxf(best, clampf(minf(rise, fall), 0.0, 1.0))
	return best


## True while a gust blows at full strength: small noises are cut (Q8).
func is_gusting(time: float) -> bool:
	return strength(time) >= 1.0


func _extend(time: float) -> void:
	var last := 0.0 if gusts.is_empty() else gusts[-1].y
	while last <= time + audio.gust_rise:
		var start := last + _rng.randf_range(audio.gust_interval.x, audio.gust_interval.y)
		var end := start + _rng.randf_range(audio.gust_length.x, audio.gust_length.y)
		gusts.append(Vector2(start, end))
		last = end
