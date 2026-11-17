class_name FootstepSounds
extends RefCounted
## The footsteps of every floor and the monster's scrape (spec S-012, T-143,
## tools/audio/footsteps.py): four variants each, never the same one twice
## in a row, at a slightly different pitch every time.

const VARIANTS := 4
const DIR := "res://assets/audio/steps/"
const PITCH_SPREAD := 0.08

static var _floors := {}
static var _monster: Array[AudioStream] = []

var _rng := RandomNumberGenerator.new()
var _last := {}


func _init(p_seed := 0) -> void:
	_rng.seed = p_seed if p_seed != 0 else randi()


## A footstep on this floor.
func step(surface: FloorSurface.Kind) -> AudioStream:
	return _pick(surface, _variants(surface))


## A step of the monster: the same scrape on every floor.
func monster_step() -> AudioStream:
	if _monster.is_empty():
		for i in VARIANTS:
			_monster.append(load(DIR + "monster_step_%d.wav" % i))
	return _pick(-1, _monster)


## A pitch around 1 for the next step.
func pitch() -> float:
	return _rng.randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)


func _variants(surface: FloorSurface.Kind) -> Array[AudioStream]:
	if not _floors.has(surface):
		var streams: Array[AudioStream] = []
		for i in VARIANTS:
			streams.append(load(DIR + "step_%s_%d.wav" % [FloorSurface.NAMES[surface], i]))
		_floors[surface] = streams
	return _floors[surface]


func _pick(key: int, streams: Array[AudioStream]) -> AudioStream:
	var index := _rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and index == _last.get(key, -1):
		index = (index + 1) % streams.size()
	_last[key] = index
	return streams[index]
