class_name Prediction
extends RefCounted
## Client-side prediction of the player's own character (S-010, Q8, T-097).
## The player moves at once with its own commands; each physics frame its
## position is recorded with the commands' number. When a snapshot says where
## the room had the player after a given command, the gap with what was
## predicted then is the error. Tiny errors are ignored, small ones are
## settled slowly over settle_time, medium ones are corrected smoothly over
## correction_time, large ones make the player jump.

## Frames kept, about 2 s at 60 frames per second.
const HISTORY := 120

var settings: NetSettings
## Correction still to apply, removed bit by bit.
var pending := Vector3.ZERO
## Whether the room has placed the player once (first snapshot).
var started := false
## Snapshots about commands up to this one describe a past already corrected.
var floor_seq := -1

var _rate := Vector3.ZERO
## A medium correction is still on its way (settling waits for its end).
var _correcting := false
var _seqs: Array[int] = []
var _positions: Array[Vector3] = []


func _init(net_settings: NetSettings) -> void:
	settings = net_settings


## Records where the player is after the frame of command seq.
func record(seq: int, position: Vector3) -> void:
	_seqs.append(seq)
	_positions.append(position)
	if _seqs.size() > HISTORY:
		_seqs.pop_front()
		_positions.pop_front()


## Starts over after the player was put somewhere by the room: the frames
## recorded so far, up to command last_seq, no longer count.
func restart(last_seq: int) -> void:
	_seqs.clear()
	_positions.clear()
	pending = Vector3.ZERO
	_correcting = false
	floor_seq = last_seq
	started = true


## Whether the frame of command seq is still recorded.
func knows(seq: int) -> bool:
	return _seqs.has(seq)


## Gap between the room and the prediction for command seq, or zero when that
## frame is no longer known.
func error_at(seq: int, server_position: Vector3) -> Vector3:
	var index := _seqs.find(seq)
	if index < 0:
		return Vector3.ZERO
	return server_position - _positions[index]


## Reads a snapshot. Returns the jump to make now (zero if none); small and
## medium gaps go into pending, applied by step().
func reconcile(seq: int, server_position: Vector3) -> Vector3:
	var error := error_at(seq, server_position)
	var gap := error.length()
	if gap >= settings.snap_threshold:
		_shift(error)
		pending = Vector3.ZERO
		_correcting = false
		return error
	if gap >= settings.correction_threshold:
		pending = error
		_rate = error / settings.correction_time
		_correcting = true
	elif gap >= settings.settle_threshold and not _correcting:
		# Small: settled slowly, so it is not kept for good (S-020, T-319),
		# unless a medium correction is still on its way.
		pending = error
		_rate = error / settings.settle_time
	return Vector3.ZERO


## Part of the pending correction to apply this frame: the whole correction
## spread evenly over correction_time (settle_time for a small one).
func step(delta: float) -> Vector3:
	if pending.is_zero_approx():
		pending = Vector3.ZERO
		_correcting = false
		return Vector3.ZERO
	var part := _rate * delta
	if part.length() >= pending.length():
		part = pending
		pending = Vector3.ZERO
		_correcting = false
	else:
		pending -= part
	_shift(part)
	return part


## Recorded positions move with a correction, so the next snapshot does not
## count it twice.
func _shift(offset: Vector3) -> void:
	for i in _positions.size():
		_positions[i] += offset
