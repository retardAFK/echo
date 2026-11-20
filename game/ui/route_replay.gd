class_name RouteReplay
extends MapView
## The routes of a game replayed fast on the plan of the map, on the end
## screen (spec S-020, T-339, piste U2): each player's line grows from the
## start, the monster in red and each hunted in its own color, with a dot
## where it is and a cross at each catch. The whole game takes replay_time
## seconds, stays replay_hold seconds, then starts again. It runs while the
## game is paused behind the end screen.

const SETTINGS := preload("res://game/data/route_settings.tres")
const LINE_WIDTH := 1.5
const HEAD_RADIUS := 2.5
const CROSS_SIZE := 3.5

var routes: RouteLog
## Seconds since the replay started.
var replay_clock := 0.0


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	super(delta)
	replay_clock += delta
	if replay_clock > SETTINGS.replay_time + SETTINGS.replay_hold:
		replay_clock = 0.0


## Shows a game's routes from the start.
func play(log: RouteLog) -> void:
	routes = log
	replay_clock = 0.0
	queue_redraw()


## Whether there is anything to replay.
func has_routes() -> bool:
	return plan != null and routes != null and not routes.is_empty()


## The game time shown now: from 0 to the end of the game, then held.
func shown_time() -> float:
	if routes == null:
		return 0.0
	return clampf(replay_clock / SETTINGS.replay_time, 0.0, 1.0) * routes.end_time


static func color_of(track: int) -> Color:
	if track == RouteLog.MONSTER:
		return MenuStyle.ROUTE_MONSTER
	return MenuStyle.ROUTE_HUNTED[(track - 1) % MenuStyle.ROUTE_HUNTED.size()]


func _draw() -> void:
	super()
	if not has_routes():
		return
	var time := shown_time()
	# The hunted first, the monster over them.
	for track in range(routes.tracks.size() - 1, -1, -1):
		_draw_track(track, time)
	for capture: Array in routes.captures:
		if capture[1] <= time:
			_draw_cross(_on_view(capture[2]))


func _on_view(point: Vector2) -> Vector2:
	return to_view(plan.to_plan(Vector3(point.x, 0.0, point.y)))


func _draw_track(track: int, time: float) -> void:
	var color := color_of(track)
	var line := PackedVector2Array()
	var last := mini(int(time / routes.sample_time), routes.size() - 1)
	for index in last + 1:
		if not routes.joined(track, index):
			_flush(line, color)
			line = PackedVector2Array()
		var point := routes.tracks[track][index]
		if point.is_finite():
			line.append(_on_view(point))
	var head := routes.position_at(track, time)
	if head.is_finite():
		if not line.is_empty():
			line.append(_on_view(head))
		draw_circle(_on_view(head), HEAD_RADIUS, color)
	_flush(line, color)


func _flush(line: PackedVector2Array, color: Color) -> void:
	if line.size() >= 2:
		draw_polyline(line, color, LINE_WIDTH, true)


func _draw_cross(at: Vector2) -> void:
	var color := MenuStyle.CREAM
	draw_line(at - Vector2.ONE * CROSS_SIZE, at + Vector2.ONE * CROSS_SIZE, color, 1.5)
	draw_line(
		at + Vector2(-CROSS_SIZE, CROSS_SIZE), at + Vector2(CROSS_SIZE, -CROSS_SIZE), color, 1.5
	)
