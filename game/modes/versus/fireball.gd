class_name Fireball
extends Node3D
## A fireball of the Versus boss (spec S-025, T-413): a glowing ball that
## flies straight, leaves embers behind it, and bursts on the first wall,
## floor or hunted it meets (or near a hunted it passes by, or at the end of
## its life). BossFire throws it and does the burst. On a client it only
## shows (harmful false): the room says where it bursts (BossFire.burst).
## Not a physics body: one ray per frame between its last and new position.

## The ground, the walls and the hunted (players and AI preys).
const LAYERS := 1 | 2 | 4
const CORE := Color(1.0, 0.82, 0.3)
const FLAME := Color(1.0, 0.4, 0.05, 0.8)
const HALO := Color(1.0, 0.18, 0.0, 0.35)
## An ember every this many seconds, and how long one glows.
const EMBER_GAP := 0.03
const EMBER_LIFE := 0.25

var fire: BossFire
var velocity := Vector3.ZERO
## On the room (or offline): it bursts and hurts. On a client: only shows.
var harmful := true
## What its ray never meets: the boss that threw it.
var thrower: CollisionObject3D
var _life := 3.0
var _ember_wait := 0.0


func _ready() -> void:
	var settings := fire.mode.settings
	_life = settings.fireball_life
	var size := settings.fireball_size
	add_child(_ball(size * 0.55, CORE))
	add_child(_ball(size, FLAME))
	add_child(_ball(size * 1.5, HALO))
	var light := OmniLight3D.new()
	light.light_color = FLAME
	light.omni_range = 7.0
	light.light_energy = 2.0
	add_child(light)


static func _ball(radius: float, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _physics_process(delta: float) -> void:
	_life -= delta
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, LAYERS)
	if thrower != null:
		query.exclude = [thrower.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = next if hit.is_empty() else hit.position
	var near: Variant = null if not harmful else fire.hunted_near(global_position, end)
	_trail(delta, end)
	global_position = end
	if near != null:
		global_position = near
	if near != null or not hit.is_empty() or _life <= 0.0:
		if harmful:
			fire.explode(global_position)
		queue_free()


## Embers along its way: small orange bursts that fade.
func _trail(delta: float, to: Vector3) -> void:
	_ember_wait -= delta
	if _ember_wait > 0.0:
		return
	_ember_wait = EMBER_GAP
	var ember := FlashBurst.new(fire.mode.settings.fireball_size * 0.9, FLAME, EMBER_LIFE)
	fire.mode.add_child(ember)
	ember.global_position = global_position.lerp(to, 0.5)
