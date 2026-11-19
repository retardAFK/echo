class_name Bench
extends Node
## Bench mode (spec S-009, Q2, T-075): the cité des Tilleuls with the AI
## monster hunting the AI prey, seen by a camera that visits fixed viewpoints
## for a fixed time. Then it shows and prints the frames per second (average,
## slowest, slowest 1 %), the worst draw calls and triangles, and the load
## time. Opened by the start menu with "?bench" in the web address, or
## "-- --bench" on the command line. The console line starts with
## "ECHO_BENCH " followed by JSON; on the web, window.echoBench holds the same.

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const SETTINGS := preload("res://game/data/bench_settings.tres")
const VISUAL_SETTINGS := preload("res://game/data/visual_settings.tres")
## Plan coordinates of the map origin (as in tools/godot/measure_map.gd).
const ORIGIN := Vector3(110, 0, 110)
## Viewpoints in plan coordinates: eye position (x, height, y), look-at point.
## Outside, inside the four visitable buildings, and the busiest places.
const VIEWS := [
	[Vector3(105, 1.6, 128), Vector3(105, 6, 100)],
	[Vector3(105, 1.6, 110), Vector3(103, 1.5, 96)],
	[Vector3(102, 1.6, 100.5), Vector3(102, 3, 94)],
	[Vector3(94, 13.6, 100), Vector3(115, 13, 100)],
	[Vector3(125, 1.6, 110), Vector3(150, 0, 102)],
	[Vector3(142, -1.4, 102), Vector3(178, -2, 108)],
	[Vector3(66, 1.6, 122), Vector3(66, 1.5, 140)],
	[Vector3(56.6, 1.6, 136), Vector3(58, 1, 146)],
	[Vector3(150, 1.6, 52), Vector3(159, 2, 70)],
	[Vector3(158, 1.6, 82), Vector3(142, 1, 64)],
	[Vector3(75, 1.6, 98), Vector3(61, 1, 81)],
	[Vector3(112, 1.6, 168), Vector3(100, 1, 153)],
]

var stats := BenchStats.new()
## Results once the tour is over, empty before.
var results := {}

var _map: GameMap
var _camera: Camera3D
var _label: Label
var _elapsed := 0.0
var _last_usec := 0
var _load_msec := 0
var _finished := false


## True when the bench is asked for: "bench" in the query string of the web
## page, or "--bench" after "--" on the command line.
static func is_requested() -> bool:
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		return query is String and (query as String).contains("bench")
	return OS.get_cmdline_user_args().has("--bench")


## Camera eye and look-at point at a time of the tour, in map coordinates.
## Each viewpoint gets the same share of the tour; the camera turns slowly
## around its look-at direction, left then right.
static func pose_at(time: float, settings: BenchSettings) -> Array[Vector3]:
	var share := settings.duration / VIEWS.size()
	var index := clampi(int(time / share), 0, VIEWS.size() - 1)
	var phase := clampf((time - index * share) / share, 0.0, 1.0)
	var view: Array = VIEWS[index]
	var eye: Vector3 = view[0] - Vector3(ORIGIN.x, 0, ORIGIN.z)
	var target: Vector3 = view[1] - Vector3(ORIGIN.x, 0, ORIGIN.z)
	var angle := deg_to_rad(settings.sweep_angle) * sin(phase * TAU)
	var look := (target - eye).rotated(Vector3.UP, angle)
	return [eye, eye + look]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.role = GameSession.Role.MONSTER
	GameSession.game_seed = SETTINGS.game_seed
	_map = load(MAP_PATH).instantiate()
	add_child(_map)
	_map.end_screen.change_scene = false
	_map.game_loop.ended.connect(_on_game_ended)
	_map.play_ai_against_ai()
	_camera = Camera3D.new()
	_camera.far = VISUAL_SETTINGS.view_distance
	add_child(_camera)
	_camera.make_current()
	_place_camera(0.0)
	_add_label()
	await get_tree().process_frame
	_load_msec = Time.get_ticks_msec()
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _finished or _last_usec == 0:
		return
	var now := Time.get_ticks_usec()
	var frame := (now - _last_usec) / 1_000_000.0
	_last_usec = now
	_elapsed += frame
	var tour_time := _elapsed - SETTINGS.warm_up
	_place_camera(maxf(tour_time, 0.0))
	if tour_time <= 0.0:
		return
	stats.add_frame(
		frame,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	)
	_label.text = Text.t("BENCH_RUNNING", ceili(SETTINGS.duration - tour_time))
	if tour_time >= SETTINGS.duration:
		_finish()


func _place_camera(time: float) -> void:
	var pose := pose_at(time, SETTINGS)
	_camera.look_at_from_position(pose[0], pose[1])


## The AIs may end the game during the tour: the bench keeps going, without
## the end screen in front of the camera.
func _on_game_ended(_hunted_won: bool) -> void:
	_map.end_screen.set_deferred("visible", false)
	get_tree().set_deferred("paused", false)


func _finish() -> void:
	_finished = true
	results = stats.to_dict()
	results["load_ms"] = _load_msec
	results["duration_s"] = SETTINGS.duration
	var window := DisplayServer.window_get_size()
	results["resolution"] = "%dx%d" % [window.x, window.y]
	results["renderer"] = RenderingServer.get_video_adapter_name()
	var line := JSON.stringify(results)
	print("ECHO_BENCH " + line)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.echoBench = %s;" % line, true)
	_label.text = (
		"\n"
		. join(
			[
				Text.t("BENCH_DONE"),
				Text.t("BENCH_FPS", [results.fps_avg, results.fps_min, results.fps_1pc_low]),
				Text.t("BENCH_DRAWS", [results.draw_calls_max, results.triangles_max]),
				Text.t("BENCH_LOAD", _load_msec / 1000.0),
				str(results.renderer),
			]
		)
	)
	get_tree().paused = true
	if not OS.has_feature("web") and OS.get_cmdline_user_args().has("--bench"):
		get_tree().quit()  # Run from the command line: the console line is enough.


func _add_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.6)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(300, 74)
	layer.add_child(panel)
	_label = Label.new()
	_label.position = Vector2(14, 12)
	_label.add_theme_font_size_override("font_size", 10)
	_label.text = Text.t("BENCH_LOADING")
	layer.add_child(_label)
