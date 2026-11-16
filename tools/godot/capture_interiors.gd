extends Node
## Screenshots of the lined interiors of the tower and the cellars (S-019), to
## compare with the mood board (tools/blender/hlm_interior_mood.py). Prints the
## draw calls and primitives of each view, like measure_map.gd.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     tools/godot/capture_interiors.tscn -- [out_dir] [view,view...]

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
	["centre_salle", Vector3(158, 1.6, 72), Vector3(142, 1.4, 69)],
	["centre_fete", Vector3(144.5, 1.6, 81), Vector3(156, 2.2, 63)],
	["centre_bureau", Vector3(164.5, 1.6, 71), Vector3(177, 1.0, 74)],
	["pharmacie", Vector3(52.5, 1.6, 146), Vector3(46, 1.2, 140)],
	["laverie_dedans", Vector3(60.5, 1.6, 140.5), Vector3(55, 0.8, 146)],
	["boulangerie", Vector3(85.5, 1.6, 140.5), Vector3(80, 1.2, 146.5)],
	["parking_tubes", Vector3(145, -1.4, 106), Vector3(165, -2.0, 99)],
	["prison", Vector3(130, -1.4, 97.8), Vector3(119, -2.0, 95.0)],
	["terminal_tour", Vector3(113.2, 1.5, 107.2), Vector3(115.3, 0.9, 106.0)],
	["terminal_centre", Vector3(149.0, 1.5, 81.3), Vector3(150.0, 0.9, 83.3)],
	["terminal_parking", Vector3(175.5, -1.5, 104.4), Vector3(176.5, -2.1, 102.4)],
	["terminal_gardien", Vector3(50.5, 1.5, 144.4), Vector3(51.5, 0.9, 146.4)],
	["cam_caves", Vector3(137.5, -0.8, 96.3), Vector3(121.0, -2.5, 95.5)],
	["cam_parking", Vector3(179.5, -0.8, 116.5), Vector3(155.0, -3.0, 103.0)],
	["cam_rampe", Vector3(127.0, 2.4, 99.6), Vector3(138.0, -2.0, 102.0)],
	["cam_hall", Vector3(115.5, 2.4, 111.5), Vector3(104.0, 1.0, 96.0)],
	["cam_centre", Vector3(159.5, 3.2, 60.5), Vector3(145.0, 0.5, 78.0)],
	["cam_galerie", Vector3(86.5, 2.8, 135.5), Vector3(50.0, 0.5, 137.0)],
	["cam_transfo", Vector3(108.0, 2.8, 160.0), Vector3(100.5, 1.0, 153.5)],
	["cam_sud_tour", Vector3(110.0, 3.3, 112.4), Vector3(105.0, 0.0, 128.0)],
	["rideau_rampe", Vector3(146.0, -1.4, 102.0), Vector3(140.0, -1.6, 102.0)],
	["rideau_galerie", Vector3(80.0, 1.6, 148.0), Vector3(86.0, 1.4, 148.0)],
	["relais_tour", Vector3(95.0, -1.5, 98.5), Vector3(95.0, -1.8, 96.0)],
	["relais_centre", Vector3(156.0, 1.5, 81.0), Vector3(156.0, 1.2, 83.7)],
	["relais_galerie", Vector3(57.0, 1.5, 147.6), Vector3(60.0, 1.0, 148.8)],
	["relais_parking", Vector3(177.6, -1.5, 99.8), Vector3(177.6, -1.8, 101.8)],
	["postit_tour", Vector3(113.6, 1.5, 106.6), Vector3(115.7, 1.4, 106.4)],
	["postit_parking", Vector3(176.7, -1.5, 104.4), Vector3(176.9, -1.6, 102.2)],
	["clavier_transfo", Vector3(108.8, 1.7, 155.0), Vector3(106.5, 0.9, 153.5)],
]
## Views whose name starts with this show a code on every post-it (T-266).
const CODE_PREFIX := "postit_"
## Views whose name starts with this show the metal shutters down (S-018).
const SHUTTER_PREFIX := "rideau_"
## Views whose name starts with this are shown as a security camera shows
## them (S-018): green and coarse.
const FEED_PREFIX := "cam_"
const FEED_SHADER := preload("res://game/fx/security_feed.gdshader")


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
	var feed := CanvasLayer.new()
	var filter := ColorRect.new()
	filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	filter.material = ShaderMaterial.new()
	(filter.material as ShaderMaterial).shader = FEED_SHADER
	feed.add_child(filter)
	add_child(feed)
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	for view: Array in VIEWS:
		if not only.is_empty() and not only.has(view[0]):
			continue
		var eye: Vector3 = view[1] - ORIGIN
		var target: Vector3 = view[2] - ORIGIN
		eye.y = view[1].y
		target.y = view[2].y
		camera.look_at_from_position(eye, target)
		feed.visible = String(view[0]).begins_with(FEED_PREFIX)
		if String(view[0]).begins_with(SHUTTER_PREFIX):
			for shutter in get_tree().get_nodes_in_group(RemoteShutter.GROUP):
				if not shutter.is_down():
					shutter.lower()
		for spot: CodeSpot in get_tree().get_nodes_in_group(CodeSpot.GROUP):
			spot.show_code("4719" if String(view[0]).begins_with(CODE_PREFIX) else "")
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-16s draw calls %4d  primitives %6d" % [view[0], draws, prims])
	get_tree().quit()
