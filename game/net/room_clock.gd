class_name RoomClock
extends RefCounted
## Client side: the room's time, read from the physics frame number each
## snapshot carries (S-020, T-320). A snapshot's room time is its frame over
## the physics rate; local time minus room time is the offset of the two
## clocks plus the trip. The clock keeps the smallest offset seen over a
## sliding window (the quickest trip: a late packet only adds to it), and
## follows it slowly, never by a jump, so the others play at an even pace even
## when snapshots come in bursts.

## Room frames per second (the room runs the same project).
var frames_per_second := float(Engine.physics_ticks_per_second)
## Seconds of snapshots the smallest offset is taken over.
var window := 2.0
## Fastest the offset follows its target, in seconds per second: the others
## play at most this much faster or slower than real time.
var max_drift := 0.02
## Beyond this gap the clock jumps to its target (a room started again).
var reset_gap := 1.0
## Local time minus room time, in seconds.
var offset := 0.0
var started := false

var _sample_times: Array[float] = []
var _sample_offsets: Array[float] = []
var _last_local := 0.0


func _init(settings: NetSettings = null) -> void:
	if settings != null:
		window = settings.clock_window
		max_drift = settings.clock_max_drift


## Room time of a frame, in seconds.
func room_time(frame: int) -> float:
	return frame / frames_per_second


## A snapshot of frame arrived at local time (seconds).
func observe(frame: int, local: float) -> void:
	var seen := local - room_time(frame)
	_sample_times.append(local)
	_sample_offsets.append(seen)
	while not _sample_times.is_empty() and _sample_times[0] < local - window:
		_sample_times.pop_front()
		_sample_offsets.pop_front()
	var target: float = _sample_offsets.min()
	if not started or absf(target - offset) > reset_gap:
		offset = target
		started = true
	else:
		var step := max_drift * maxf(local - _last_local, 0.0)
		offset = move_toward(offset, target, step)
	_last_local = local


## Room time now, at local time (seconds).
func now(local: float) -> float:
	return local - offset
