class_name ThrownBottle
extends RigidBody3D
## A bottle the hunted threw (spec S-008, Q2). It flies on its own and breaks
## at the first thing it touches, ground or wall: an IMPACT noise of 8 m where
## it breaks, the sound of glass, and a few shards left on the ground for a
## while. One that touched nothing after a few seconds breaks where it is.

signal shattered(at: Vector3)

## How far below the breaking point the shards look for the ground, in meters.
const SHARDS_DROP := 3.0
## The sound of the break carries this far for the ears, in meters.
const SOUND_DISTANCE := 30.0
const GLASS_SOUND := preload("res://assets/audio/ruses/glass_break.wav")

@export var settings: RuseSettings

var _flight := 0.0
var _broken := false


## Distance a bottle flies on flat ground before landing, in meters, when
## thrown level with this lift from this height (pure ballistics, no drag).
static func flat_range(speed: float, lift_degrees: float, height: float, gravity: float) -> float:
	var lift := deg_to_rad(lift_degrees)
	var up := speed * sin(lift)
	var time := (up + sqrt(up * up + 2.0 * gravity * height)) / gravity
	return speed * cos(lift) * time


## Speed to throw at so that a bottle lands this far on flat ground, capped
## (the AI prey aims, S-008), in meters per second.
static func speed_for_range(
	distance: float, lift_degrees: float, height: float, gravity: float, max_speed: float
) -> float:
	var low := 0.5
	var high := max_speed
	for i in 24:
		var middle := (low + high) / 2.0
		if flat_range(middle, lift_degrees, height, gravity) < distance:
			low = middle
		else:
			high = middle
	return high


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1
	continuous_cd = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_flight += delta
	if _flight >= settings.bottle_max_flight:
		shatter()


## Breaks the bottle where it is: noise, sound, shards.
func shatter() -> void:
	if _broken:
		return
	_broken = true
	var at := global_position
	NoiseBus.emit_noise(NoiseEvent.Type.IMPACT, at, settings.impact_range, self)
	_leave_shards(at)
	shattered.emit(at)
	queue_free()


func _on_body_entered(_body: Node) -> void:
	shatter()


## A few dark green shards on the ground below the break, and the sound of
## glass played from there.
func _leave_shards(at: Vector3) -> void:
	var ground := at
	var query := PhysicsRayQueryParameters3D.create(
		at, at + Vector3.DOWN * SHARDS_DROP, collision_mask
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ground = hit.position
	var shards := Node3D.new()
	shards.name = "Shards"
	get_parent().add_child(shards)
	shards.global_position = ground
	var mesh := MeshInstance3D.new()
	mesh.mesh = $Mesh.mesh
	mesh.rotation = Vector3(PI / 2.0, randf() * TAU, 0.0)
	mesh.scale = Vector3(1.0, 0.4, 0.2)
	mesh.position.y = 0.01
	shards.add_child(mesh)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = GLASS_SOUND
	sound.max_distance = SOUND_DISTANCE
	shards.add_child(sound)
	sound.play()
	if settings.shards_time > 0.0:
		get_tree().create_timer(settings.shards_time).timeout.connect(shards.queue_free)
