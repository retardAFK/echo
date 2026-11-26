class_name Flare
extends Node3D
## A Versus flare (spec S-024, Q13, T-372): flies in an arc (ShotMath.step),
## hits the boss's body or face, or lands and burns a while. Not a physics
## body: one ray per frame between its last and its new position. Only the
## newest settings.flare_lights flares have a real light (VersusMode.add_flare).

const LAYERS := 1 | 2 | 8  # Walls, props, monsters.
const COLOR := Color(1.0, 0.25, 0.2)
const SIZE := 0.07

var velocity := Vector3.ZERO
## Who shot it: never hit, and credited for the hit.
var shooter: Node3D
var mode: VersusMode
var light: OmniLight3D
var _life := 0.0
var _landed := false


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SIZE
	sphere.height = SIZE * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	sphere.material = material
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	light = OmniLight3D.new()
	light.light_color = COLOR
	light.omni_range = mode.settings.flare_light_range
	light.light_energy = 1.6
	add_child(light)
	_life = mode.settings.flare_life


func _physics_process(delta: float) -> void:
	_life -= delta
	if _landed:
		if _life <= 0.0:
			queue_free()
		return
	if _life <= 0.0:
		queue_free()
		return
	var step := ShotMath.step(global_position, velocity, mode.settings.flare_gravity, delta)
	var next: Vector3 = step[0]
	velocity = step[1]
	var query := PhysicsRayQueryParameters3D.create(global_position, next, LAYERS)
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
		return
	global_position = hit.position
	var boss := mode.boss_of(hit.collider as Node)
	if boss != null:
		boss.take_flare(self, hit.position)
		queue_free()
		return
	_landed = true  # It burns on the ground or against the wall (Q13).
	_life = mode.settings.flare_ground_time
