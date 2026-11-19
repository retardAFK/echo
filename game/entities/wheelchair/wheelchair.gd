class_name Wheelchair
extends CharacterBody3D
## A hospital wheelchair (spec S-014, Q7). A hunted launches it with
## "interact" along its aim: it rolls on its own, slowing down, for about
## wheelchair_distance, squeaking (a ROLL noise of wheelchair_range every
## roll_interval at where it is). A decoy that moves. Once stopped, it can
## be launched again.

const GROUP := &"wheelchairs"

@export var settings: HospitalSettings

## Online client: the room moves it.
var mirror := false

var _next_roll := 0.0
## Pose last sent online, resent once it moved (S-020, T-302).
var _shared := SharedPose.new()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)
	DrawRange.limit(self, DrawRange.INDOOR)


func is_rolling() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.05


## Slowing down so that a launch at wheelchair_speed stops after
## wheelchair_distance, in m/s².
func braking() -> float:
	return (
		settings.wheelchair_speed * settings.wheelchair_speed / (2.0 * settings.wheelchair_distance)
	)


func can_interact(from: Vector3) -> bool:
	if is_rolling():
		return false
	var gap := global_position - from
	return Vector2(gap.x, gap.z).length() <= settings.wheelchair_reach and absf(gap.y) < 1.5


## Only the hunted launch it.
func wanted_by(who: Node) -> bool:
	return not Door.is_monster(who) and not is_rolling()


func get_prompt() -> String:
	return "HUD_INTERACT_WHEELCHAIR" if not is_rolling() else ""


## Launched by a hunted along its aim.
func interact(who: Node = null) -> void:
	if who == null or not wanted_by(who):
		return
	var heading := -(who as Node3D).global_basis.z
	launch(Vector3(heading.x, 0.0, heading.z).normalized())


func launch(direction: Vector3) -> void:
	velocity.x = direction.x * settings.wheelchair_speed
	velocity.z = direction.z * settings.wheelchair_speed
	rotation.y = atan2(-direction.x, -direction.z)
	_next_roll = 0.0


func _physics_process(delta: float) -> void:
	if mirror:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var flat := Vector2(velocity.x, velocity.z)
	var speed := flat.length()
	if speed > 0.0:
		var slower := maxf(speed - braking() * delta, 0.0)
		flat = flat * (slower / speed)
		velocity.x = flat.x
		velocity.z = flat.y
	if not is_rolling() and is_on_floor():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	move_and_slide()
	if is_rolling():
		_next_roll -= delta
		if _next_roll <= 0.0:
			_next_roll = settings.roll_interval
			NoiseBus.emit_noise(
				NoiseEvent.Type.ROLL, global_position, settings.wheelchair_range, self
			)


## Online: [x, y, z, yaw], as last sent: resent once it moved (S-020, T-302).
func state() -> Array:
	return _shared.of(self)


## Online client: where the room says it is.
func mirror_state(values: Array) -> void:
	global_position = Vector3(values[0], values[1], values[2])
	rotation.y = values[3]
