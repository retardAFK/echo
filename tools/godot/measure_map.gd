extends Node
## Renders the cité des Tilleuls from a few viewpoints (spec S-006): saves a
## screenshot of each and prints draw calls, triangles and nearby lights, to
## check the performance budget (constitution 2.2) and the landmarks in the fog.
## Needs a real renderer, not --headless:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     tools/godot/measure_map.tscn -- [out_dir]
## Screenshots go to out_dir (default: user://measure).

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
## Frames to wait at each viewpoint before measuring.
const SETTLE_FRAMES := 8
## Lights closer than this are counted as visible (the fog hides the rest).
const LIGHT_VISIBLE_DISTANCE := 25.0

## Viewpoints in plan coordinates: name, eye position (x, height, y), look-at point.
const VIEWS := [
	["centre_tour", Vector3(105, 1.6, 128), Vector3(105, 6, 100)],
	["aire_de_jeux", Vector3(75, 1.6, 98), Vector3(61, 1, 81)],
	["porche_sortie", Vector3(155, 1.6, 60), Vector3(155, 2, 12)],
	["galerie", Vector3(66, 1.6, 122), Vector3(66, 1.5, 140)],
	["parking", Vector3(125, 1.6, 110), Vector3(150, 0, 102)],
	["centre_social", Vector3(150, 1.6, 52), Vector3(159, 2, 70)],
	["transformateur", Vector3(112, 1.6, 168), Vector3(100, 1, 153)],
	["city_stade", Vector3(160, 1.6, 172), Vector3(163, 1, 190)],
	["vue_haute", Vector3(60, 40, 230), Vector3(110, 0, 110)],
	["tour_hall", Vector3(105, 1.6, 110), Vector3(103, 1.5, 96)],
	["tour_escalier", Vector3(102, 1.6, 100.5), Vector3(102, 3, 94)],
	["tour_palier_4", Vector3(94, 13.6, 100), Vector3(115, 13, 100)],
	["parking_dedans", Vector3(142, -1.4, 102), Vector3(178, -2, 108)],
	["laverie", Vector3(56.6, 1.6, 136), Vector3(58, 1, 146)],
	["salle_centre_social", Vector3(158, 1.6, 82), Vector3(142, 1, 64)],
]

var _origin := Vector3(110, 0, 110)


func _ready() -> void:
	var out_dir := "user://measure"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var map: Node3D = load(MAP_PATH).instantiate()
	add_child(map)
	var camera := Camera3D.new()
	add_child(camera)
	await get_tree().process_frame
	camera.far = map.get_node("Player/Head/Camera3D").far
	camera.make_current()
	var lights := map.find_children("*", "Light3D", true, false)
	for view: Array in VIEWS:
		var eye: Vector3 = view[1] - _origin
		var target: Vector3 = view[2] - _origin
		eye.y = view[1].y
		target.y = view[2].y
		camera.look_at_from_position(eye, target)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var near := 0
		for light: Light3D in lights:
			if light is OmniLight3D and light.global_position.distance_to(eye) < LIGHT_VISIBLE_DISTANCE:
				near += 1
		var image := get_viewport().get_texture().get_image()
		image.save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-16s draw calls %4d  primitives %6d  lights < 25 m %d" % [view[0], draws, prims, near])
	get_tree().quit()
