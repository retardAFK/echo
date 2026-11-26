extends Node
## Screenshots of the Versus arena as a player sees it (spec S-025, T-401 and
## T-405), to check the open doors, the look and the effects with one's own
## eyes, and prints the draw calls of each view. The map plays a Versus game
## with the AI boss; a camera of its own takes each view.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     res://tools/godot/capture_versus.tscn -- [out_dir] [view,view...]

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const SETTLE_FRAMES := 12
const VISUAL_SETTINGS := preload("res://game/data/visual_settings.tres")
const ORIGIN := Vector3(110, 0, 110)

## Name, eye (plan x, height, plan y), look-at point.
const VIEWS := [
	["place", Vector3(96, 1.7, 122), Vector3(130, 2.0, 95)],
	["porte_tour_sud", Vector3(108, 1.7, 118), Vector3(108, 1.4, 108)],
	["hall_tour", Vector3(108, 1.7, 106), Vector3(108, 1.4, 96)],
	["centre_social_ouest", Vector3(132, 1.7, 72), Vector3(145, 1.4, 72)],
	["toit_centre", Vector3(150, 6.0, 80), Vector3(120, 2.0, 100)],
	["parking", Vector3(150, 1.7, 120), Vector3(170, 1.0, 100)],
]


func _ready() -> void:
	var out_dir := "user://versus"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED
	var map: Node3D = load(MAP_PATH).instantiate()
	add_child(map)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var camera := Camera3D.new()
	add_child(camera)
	camera.far = VISUAL_SETTINGS.view_distance
	camera.near = VISUAL_SETTINGS.near_clip
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	for view: Array in VIEWS:
		if not only.is_empty() and not only.has(view[0]):
			continue
		camera.make_current()
		var eye: Vector3 = view[1] - ORIGIN
		var target: Vector3 = view[2] - ORIGIN
		eye.y = view[1].y
		target.y = view[2].y
		camera.look_at_from_position(eye, target)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-20s draw calls %4d" % [view[0], draws])
	get_tree().quit()
