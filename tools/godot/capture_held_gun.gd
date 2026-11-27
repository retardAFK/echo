extends Node
## Screenshots of a hunted holding each Versus gun (spec S-025, T-409), from
## the front three-quarter, the side and the back, to check the arms' pose
## (HoldPose) and the gun's place with one's own eyes.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     res://tools/godot/capture_held_gun.tscn -- [out_dir]

const HUNTED_BODY := preload("res://game/entities/hunted_body/hunted_body.tscn")
const GUNS: Array[StringName] = [&"light_smg", &"precision_rifle", &"sonic_shotgun"]
## Camera eye, by view name (the body stands at the origin, facing -Z).
const VIEWS := {
	"face": Vector3(1.6, 1.5, -2.2),
	"cote": Vector3(2.6, 1.3, 0.0),
	"dos": Vector3(0.9, 1.9, 2.6),
}


func _ready() -> void:
	var out_dir := "user://held_gun"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.7, 0.9)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0.0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()
	var gaits := {"": PlayerMotion.Gait.WALK, "_accroupi": PlayerMotion.Gait.CROUCH}
	for gun_id in GUNS:
		for gait_name: String in gaits:
			var body: HuntedBody = HUNTED_BODY.instantiate()
			add_child(body)
			if OS.get_environment("NO_HOLD") == "":
				body.hold(
					GunModel.instance(gun_id, Color(1.0, 0.72, 0.15)), GunModel.fore_grip(gun_id)
				)
			for i in 20:
				body.show_state(gaits[gait_name], 0.0, false)
				await get_tree().process_frame
			for view: String in VIEWS:
				camera.look_at_from_position(VIEWS[view], Vector3(0.0, 1.0, -0.2))
				await get_tree().process_frame
				await get_tree().process_frame
				var file := "%s%s_%s.png" % [gun_id, gait_name, view]
				get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
			body.free()
	get_tree().quit()
