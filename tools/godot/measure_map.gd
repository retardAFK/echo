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
## Lights closer than this, in view and not behind a wall, count as visible
## (the fog hides the rest; constitution 2.2 allows 4).
const LIGHT_VISIBLE_DISTANCE := 25.0
const VISUAL_SETTINGS := preload("res://game/data/visual_settings.tres")

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
	["barre_c", Vector3(42, 1.6, 100), Vector3(27, 7, 92)],
	["barre_b_porche", Vector3(162, 1.6, 52), Vector3(153, 5, 34)],
	["tour_dehors", Vector3(128, 1.6, 128), Vector3(106, 18, 102)],
	["barre_g", Vector3(160, 1.6, 132), Vector3(172, 5, 145)],
	["tour_fenetre", Vector3(110, 7.6, 92), Vector3(110, 7, 80)],
	["boxes", Vector3(26, 1.6, 172), Vector3(17, 1.2, 164)],
	["balancoire", Vector3(66, 1.6, 90), Vector3(60, 1.2, 79)],
	["voiture", Vector3(40, 1.6, 51), Vector3(36, 0.6, 45)],
	["lampadaire", Vector3(126, 1.6, 58), Vector3(130, 0, 48)],
	["lampadaire_loin", Vector3(122, 1.6, 82), Vector3(130, 0, 48)],
	# Furnished interiors (S-016, T-241).
	["tour_appartement", Vector3(108, 7.6, 102), Vector3(115, 7, 108)],
	["tour_appartement_nord", Vector3(109, 4.6, 98), Vector3(93, 4, 92)],
	["galerie_boutiques", Vector3(64, 1.6, 141), Vector3(78, 1, 143)],
	["centre_cuisine", Vector3(153, 1.6, 79), Vector3(159, 1, 83)],
	["centre_scene", Vector3(152, 1.6, 70), Vector3(141, 1.5, 70)],
	# Final check of S-016 (T-244): another landing, the cellars.
	["tour_palier_2", Vector3(94, 7.6, 100), Vector3(115, 7, 100)],
	["caves", Vector3(100, -1.4, 97.2), Vector3(135, -2, 97.2)],
]

## Grid step of the sweep, in meters.
const SWEEP_STEP := 20

var _origin := Vector3(110, 0, 110)


func _ready() -> void:
	var out_dir := "user://measure"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var started := Time.get_ticks_usec()
	var map: Node3D = load(MAP_PATH).instantiate()
	add_child(map)
	print("Map loaded and instanced in %d ms" % ((Time.get_ticks_usec() - started) / 1000))
	var camera := Camera3D.new()
	add_child(camera)
	await get_tree().process_frame
	camera.far = VISUAL_SETTINGS.view_distance
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
		var near := _visible_lights(camera, eye, lights)
		var image := get_viewport().get_texture().get_image()
		image.save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-20s draw calls %4d  primitives %6d  visible lights %d" % [view[0], draws, prims, near])
	if not OS.get_cmdline_user_args().has("--no-sweep"):
		await _sweep(camera, lights)
	get_tree().quit()


## Lights that light something on screen: in view, not behind a wall, near
## enough to be seen in the fog, and not faded out by distance (T-049).
func _visible_lights(camera: Camera3D, eye: Vector3, lights: Array) -> int:
	var near := 0
	var space := get_viewport().get_world_3d().direct_space_state
	for light: Light3D in lights:
		if not (light is OmniLight3D and light.is_visible_in_tree()):
			continue
		var at := light.global_position
		var distance := at.distance_to(eye)
		if distance > LIGHT_VISIBLE_DISTANCE + light.omni_range:
			continue
		if light.distance_fade_enabled:
			if distance > light.distance_fade_begin + light.distance_fade_length:
				continue
		if not camera.is_position_in_frustum(at):
			continue
		var ray := PhysicsRayQueryParameters3D.create(eye, at, 3)
		if space.intersect_ray(ray).is_empty():
			near += 1
	return near


## Looks around from every node of a 20 m grid, at eye height, to find the
## busiest place of the map.
func _sweep(camera: Camera3D, lights: Array) -> void:
	var worst := 0
	var worst_at := ""
	var most_lights := 0
	var total := 0
	var count := 0
	for gx in range(SWEEP_STEP / 2, 220, SWEEP_STEP):
		for gy in range(SWEEP_STEP / 2, 220, SWEEP_STEP):
			var eye := Vector3(gx, 1.6, gy) - Vector3(_origin.x, 0, _origin.z)
			for heading in 4:
				var target := eye + Vector3.FORWARD.rotated(Vector3.UP, heading * PI / 2.0)
				camera.look_at_from_position(eye, target)
				await get_tree().process_frame
				await get_tree().process_frame
				var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				total += draws
				count += 1
				most_lights = maxi(most_lights, _visible_lights(camera, eye, lights))
				if draws > worst:
					worst = draws
					worst_at = "(%d, %d) heading %d" % [gx, gy, heading * 90]
	print("Sweep: %d views, mean %d draw calls, worst %d at %s" % [count, total / count, worst, worst_at])
	print("Sweep: at most %d visible lights" % most_lights)
