class_name AmbientTrain
extends AudioStreamPlayer3D
## A distant train passing on the embankment now and then (spec S-006, T-050).
## The sound slides along the track while it plays. Like every ambient sound,
## it does not go through NoiseBus: it betrays nobody.

## The track, in local coordinates of the parent: the sound goes from one end
## to the other during the pass, in a random direction.
@export var track_start := Vector3.ZERO
@export var track_end := Vector3.ZERO
## Seconds of silence between two trains.
@export var min_wait := 45.0
@export var max_wait := 110.0
## Seconds before the first train.
@export var first_wait := 15.0

var passes := 0

var _wait := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_wait = first_wait
	position = track_start


func _process(delta: float) -> void:
	if playing:
		var length := stream.get_length() if stream else 1.0
		position = _from.lerp(_to, clampf(get_playback_position() / length, 0.0, 1.0))
		return
	_wait -= delta
	if _wait <= 0.0:
		start_pass()


## Starts a train now, and schedules the next one.
func start_pass() -> void:
	var forward := _rng.randf() < 0.5
	_from = track_start if forward else track_end
	_to = track_end if forward else track_start
	position = _from
	passes += 1
	_wait = _rng.randf_range(min_wait, max_wait)
	play()
