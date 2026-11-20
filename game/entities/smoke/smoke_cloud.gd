class_name SmokeCloud
extends Node3D
## A smoke bomb's cloud (S-020, T-335, piste R4): set off at the hunted's
## feet, it cuts sight through it for smoke_time seconds, both ways. Every
## sight test asks blocks(): MonsterVision.has_line_of_sight (the AI monster
## and the AI hunted), NetGame.sees (what the room sends each player, which
## NetVisibility filters) and ChaseWatch.sees. The cloud is a sphere of
## smoke_radius around a centre smoke_height above the node, growing over
## smoke_grow_time. Online, the clients' copies only show it and hiss.

signal faded

## Group of the clouds in the world.
const GROUP := &"smoke_clouds"

## The clouds cutting sight now, wherever they are (no tree needed by the
## pure sight tests).
static var _active: Array[SmokeCloud] = []

@export var settings: RuseSettings

## Seconds since it went off.
var age := 0.0
var done := false

@onready var _particles: CPUParticles3D = $Particles
@onready var _hiss: AudioStreamPlayer3D = $Hiss


## Whether any cloud stands between two points. Closer than
## smoke_clear_distance, they still see each other.
static func blocks(from: Vector3, to: Vector3) -> bool:
	for cloud in _active:
		if is_instance_valid(cloud) and cloud.cuts(from, to):
			return true
	return false


## Sets the cloud off at user's feet (GadgetDef contract, S-023, T-351).
## Returns the ruse it counts as.
func deploy(user: Player) -> StringName:
	user.get_parent().add_child(self)
	global_position = user.global_position
	NoiseBus.emit_noise(
		NoiseEvent.Type.THROW, user.global_position, user.ruse_settings.gesture_range, user
	)
	return &"smoke"


func _ready() -> void:
	add_to_group(GROUP)
	_active.append(self)
	_particles.position = Vector3.UP * settings.smoke_height
	_particles.emission_sphere_radius = settings.smoke_radius * 0.75
	_particles.emitting = true
	SoundSpace.play(_hiss)


func _exit_tree() -> void:
	_active.erase(self)


func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	if age >= settings.smoke_time:
		done = true
		_active.erase(self)
		_particles.emitting = false
		faded.emit()
		get_tree().create_timer(_particles.lifetime).timeout.connect(queue_free)


## Radius cutting sight now: it grows, then is gone once done.
func radius() -> float:
	if done:
		return 0.0
	if settings.smoke_grow_time <= 0.0:
		return settings.smoke_radius
	return settings.smoke_radius * clampf(age / settings.smoke_grow_time, 0.0, 1.0)


## The centre of the cloud, in world space.
func centre() -> Vector3:
	return global_position + Vector3.UP * settings.smoke_height


## Whether this cloud stands between two points.
func cuts(from: Vector3, to: Vector3) -> bool:
	var reach := radius()
	if reach <= 0.0 or from.distance_to(to) <= settings.smoke_clear_distance:
		return false
	var closest := Geometry3D.get_closest_point_to_segment(centre(), from, to)
	return closest.distance_to(centre()) <= reach
