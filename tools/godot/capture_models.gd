extends Node
## Studio shots of models, one PNG each, to show them before they go in the
## game (S-018, T-269: Maxime sees the renders).
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     tools/godot/capture_models.tscn -- <out_dir> <res://a.glb> [size] ...

const SETTLE_FRAMES := 6


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	get_window().size = Vector2i(640, 480)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.12, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.52)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	for path in args.slice(1):
		var model: Node3D = (load(path) as PackedScene).instantiate()
		add_child(model)
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var part := mesh.global_transform * mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		var centre := box.get_center()
		var radius := box.size.length() * 0.5
		var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.15
		camera.position = centre + Vector3(0.55, 0.45, 0.75).normalized() * distance
		camera.look_at(centre, Vector3.UP)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(out.path_join(path.get_file().get_basename() + ".png"))
		model.free()
	get_tree().quit()
