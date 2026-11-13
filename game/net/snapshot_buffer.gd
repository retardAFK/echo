class_name SnapshotBuffer
extends RefCounted
## Positions of another player received from the room, with the local time
## they arrived (S-010, Q8, T-097). The player is shown interpolation_delay
## in the past, between the two snapshots around that time; past the newest,
## it keeps its last speed for at most max_extrapolation, then stops.

## Older snapshots are dropped beyond this many.
const MAX_ENTRIES := 32

var _times: Array[float] = []
var _positions: Array[Vector3] = []
var _yaws: Array[float] = []


## Adds a snapshot arrived at time (seconds). Out-of-order ones are dropped.
func push(time: float, position: Vector3, yaw: float) -> void:
	if not _times.is_empty() and time <= _times[-1]:
		return
	_times.append(time)
	_positions.append(position)
	_yaws.append(yaw)
	if _times.size() > MAX_ENTRIES:
		_times.pop_front()
		_positions.pop_front()
		_yaws.pop_front()


func is_empty() -> bool:
	return _times.is_empty()


## Position and yaw to show at time, as [Vector3, float].
func sample(time: float, max_extrapolation: float) -> Array:
	if _times.is_empty():
		return [Vector3.ZERO, 0.0]
	if time <= _times[0]:
		return [_positions[0], _yaws[0]]
	for i in range(1, _times.size()):
		if time <= _times[i]:
			var weight := inverse_lerp(_times[i - 1], _times[i], time)
			return [
				_positions[i - 1].lerp(_positions[i], weight),
				lerp_angle(_yaws[i - 1], _yaws[i], weight),
			]
	var last := _times.size() - 1
	if last == 0:
		return [_positions[0], _yaws[0]]
	var span := _times[last] - _times[last - 1]
	var velocity := (_positions[last] - _positions[last - 1]) / maxf(span, 0.001)
	var ahead := minf(time - _times[last], max_extrapolation)
	return [_positions[last] + velocity * ahead, _yaws[last]]
