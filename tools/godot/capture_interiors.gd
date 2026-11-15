extends Node
## Screenshots of the lined interiors of the tower and the cellars (S-019), to
## compare with the mood board (tools/blender/hlm_interior_mood.py). Prints the
## draw calls and primitives of each view, like measure_map.gd.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     tools/godot/capture_interiors.tscn -- [out_dir]

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
const SETTLE_FRAMES := 8
const VISUAL_SETTINGS := preload("res://game/data/visual_settings.tres")
const ORIGIN := Vector3(110, 0, 110)

## Name, eye (plan x, height, plan y), look-at point.
const VIEWS := [
	["hall_boites", Vector3(108, 1.6, 101), Vector3(115, 1.2, 94)],
	["hall_ascenseur", Vector3(110, 1.6, 108), Vector3(101, 1.2, 92)],
	["escalier_monte", Vector3(102, 1.6, 98.2), Vector3(102, 3.2, 93)],
	["palier_2", Vector3(93, 4.6, 100), Vector3(115, 4.2, 100)],
	["palier_3_est", Vector3(115, 7.6, 100), Vector3(93, 7.2, 100)],
	["salon_tele", Vector3(113, 4.6, 106), Vector3(109.6, 3.8, 104)],
	["salon_nord", Vector3(110, 7.6, 97), Vector3(106, 7.6, 88.5)],
	["cuisine_sud", Vector3(96, 10.6, 108), Vector3(93, 10, 111.5)],
	["chambre_sud", Vector3(103, 4.6, 108), Vector3(99, 4.1, 110.5)],
	["caves", Vector3(100, -1.4, 97.2), Vector3(130, -1.8, 97.2)],
]


func _ready() -> void:
	var out_dir := "user://interiors"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var map: Node3D = load(MAP_PATH).instantiate()
	add_child(map)
	var camera := Camera3D.new()
	add_child(camera)
	await get_tree().process_frame
	camera.far = VISUAL_SETTINGS.view_distance
	camera.near = VISUAL_SETTINGS.near_clip
	camera.make_current()
	for view: Array in VIEWS:
		var eye: Vector3 = view[1] - ORIGIN
		var target: Vector3 = view[2] - ORIGIN
		eye.y = view[1].y
		target.y = view[2].y
		camera.look_at_from_position(eye, target)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-16s draw calls %4d  primitives %6d" % [view[0], draws, prims])
	get_tree().quit()
