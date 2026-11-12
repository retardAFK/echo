class_name BenchStats
extends RefCounted
## Frame statistics of the bench mode (spec S-009, Q2, T-075): frames per
## second on average, at the slowest frame and over the slowest 1 % of frames,
## plus the worst draw calls and triangles seen. Pure logic, testable without
## a scene.

## Share of the slowest frames averaged for the "1 % low" figure.
const LOW_SHARE := 0.01

var worst_draw_calls := 0
var worst_triangles := 0

var _frame_times: PackedFloat64Array = []


## Adds one frame: its duration in seconds, its draw calls and triangles.
func add_frame(seconds: float, draw_calls := 0, triangles := 0) -> void:
	if seconds <= 0.0:
		return
	_frame_times.append(seconds)
	worst_draw_calls = maxi(worst_draw_calls, draw_calls)
	worst_triangles = maxi(worst_triangles, triangles)


func frame_count() -> int:
	return _frame_times.size()


## Frames per second over the whole run (frames divided by time).
func average_fps() -> float:
	if _frame_times.is_empty():
		return 0.0
	var total := 0.0
	for t in _frame_times:
		total += t
	return _frame_times.size() / total


## Frames per second of the slowest frame.
func min_fps() -> float:
	if _frame_times.is_empty():
		return 0.0
	var slowest := 0.0
	for t in _frame_times:
		slowest = maxf(slowest, t)
	return 1.0 / slowest


## Frames per second over the slowest 1 % of frames (at least one frame).
func low_fps() -> float:
	if _frame_times.is_empty():
		return 0.0
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var count := maxi(1, int(ceil(sorted.size() * LOW_SHARE)))
	var total := 0.0
	for i in count:
		total += sorted[sorted.size() - 1 - i]
	return count / total


## Everything at once, rounded for the screen and the console.
func to_dict() -> Dictionary:
	return {
		"frames": frame_count(),
		"fps_avg": snappedf(average_fps(), 0.1),
		"fps_min": snappedf(min_fps(), 0.1),
		"fps_1pc_low": snappedf(low_fps(), 0.1),
		"draw_calls_max": worst_draw_calls,
		"triangles_max": worst_triangles,
	}
