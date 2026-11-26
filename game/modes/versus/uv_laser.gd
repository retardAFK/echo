class_name UvLaser
extends Node
## The lance-laser UV (spec S-024, Q13, T-377): while its hunted holds the
## trigger and the battery lasts, an instant beam of laser_range along the
## aim; on the boss it burns laser_damage_per_second (twice in the face) and
## slows it. It hums (a small noise each laser_noise_interval). Let go, the
## battery fills again in laser_recharge. A child of a HunterKit.

const BEAM_COLOR := Color(0.62, 0.3, 1.0)
const BEAM_WIDTH := 0.025
## Where the beam leaves from, beside and under the eyes.
const MUZZLE := Vector3(0.18, -0.2, 0.0)

var kit: HunterKit
## Seconds of beam left in the battery.
var battery := 0.0
## True while the beam is on this frame.
var firing := false
var _hum_left := 0.0
var _beam: MeshInstance3D


func _init(p_kit: HunterKit) -> void:
	kit = p_kit
	name = "UvLaser"


func _ready() -> void:
	battery = kit.mode.settings.laser_battery
	_beam = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_WIDTH
	mesh.bottom_radius = BEAM_WIDTH
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = BEAM_COLOR
	mesh.material = material
	_beam.mesh = mesh
	_beam.top_level = true
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


## Share of the battery left, for the HUD.
func ratio() -> float:
	return battery / kit.mode.settings.laser_battery


## One frame of the trigger held (held) or not.
func update(held: bool, delta: float) -> void:
	var settings := kit.mode.settings
	firing = held and battery > 0.0
	_beam.visible = firing
	if not firing:
		battery = minf(
			battery + delta * settings.laser_battery / settings.laser_recharge,
			settings.laser_battery
		)
		return
	battery = maxf(battery - delta, 0.0)
	_hum_left -= delta
	if _hum_left <= 0.0:
		_hum_left = settings.laser_noise_interval
		NoiseBus.emit_noise(NoiseEvent.Type.SHOT, kit.eye(), settings.laser_noise_range, kit.body)
	var from := kit.eye()
	var to := from + kit.aim() * settings.laser_range
	var query := PhysicsRayQueryParameters3D.create(from, to, Flare.LAYERS)
	query.exclude = [kit.body.get_rid()]
	var hit := kit.body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		to = hit.position
		var boss := kit.mode.boss_of(hit.collider)
		if boss != null:
			boss.take_laser(kit.body, to, delta)
	_draw_beam(from + kit.body.global_basis * MUZZLE, to)


func _draw_beam(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		_beam.visible = false
		return
	var middle := (from + to) / 2.0
	var up := (to - from).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up * length, side.cross(up))  # The cylinder is 1 m long.
	_beam.global_transform = Transform3D(basis, middle)


func _exit_tree() -> void:
	firing = false
