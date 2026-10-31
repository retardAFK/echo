class_name Player
extends CharacterBody3D
## First-person player controller (spec S-001).
## Movement math lives in PlayerMotion, tunable values in PlayerSettings.

## Emitted when the player switches between crouching, walking and sprinting.
## The noise system (S-002) listens to it.
signal gait_changed(gait: PlayerMotion.Gait)

@export var settings: PlayerSettings

var _gait := PlayerMotion.Gait.WALK
var _wants_crouch := false
var _pitch := 0.0
var _height := 0.0
var _bob_phase := 0.0
var _capsule: CapsuleShape3D
var _headroom_sphere: SphereShape3D

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _headroom_cast: ShapeCast3D = $HeadroomCast


func _ready() -> void:
	# Each player owns its capsule, so resizing it never touches another instance.
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_capsule.radius = settings.capsule_radius
	_headroom_sphere = SphereShape3D.new()
	_headroom_sphere.radius = settings.capsule_radius
	_headroom_cast.shape = _headroom_sphere
	_apply_height(settings.standing_height)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crouch"):
		toggle_crouch()
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only allow pointer capture right after a user gesture.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.screen_relative)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_set_gait(
		PlayerMotion.resolve_gait(
			_wants_crouch,
			Input.is_action_pressed("sprint"),
			not input.is_zero_approx(),
			_gait == PlayerMotion.Gait.CROUCH,
			_has_headroom()
		)
	)
	var target_speed := PlayerMotion.speed_for_gait(settings, _gait)
	var target := PlayerMotion.wish_direction(input, rotation.y) * target_speed
	var horizontal := PlayerMotion.approach_velocity(
		Vector3(velocity.x, 0.0, velocity.z), target, settings, delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var step := _step_up_height(horizontal * delta)
	if step > 0.0:
		global_position.y += step
	move_and_slide()
	_update_height(delta)
	_update_head_bob(horizontal.length(), target_speed, delta)


## Turns the body (yaw) and the head (pitch) from a mouse movement in screen pixels.
func look(relative: Vector2) -> void:
	var sensitivity := deg_to_rad(settings.mouse_sensitivity)
	rotate_y(-relative.x * sensitivity)
	_pitch = PlayerMotion.clamp_pitch(_pitch - relative.y * sensitivity, settings)
	_head.rotation.x = _pitch


## Switches between crouching and standing (crouch key, toggle mode).
func toggle_crouch() -> void:
	_wants_crouch = not _wants_crouch


func get_pitch() -> float:
	return _pitch


func get_gait() -> PlayerMotion.Gait:
	return _gait


func get_height() -> float:
	return _height


func _set_gait(gait: PlayerMotion.Gait) -> void:
	if gait == _gait:
		return
	_gait = gait
	gait_changed.emit(gait)


func _has_headroom() -> bool:
	if is_equal_approx(_height, settings.standing_height):
		return true
	# Sweep a sphere from the top of the current capsule up to the standing height.
	_headroom_cast.position.y = _height - settings.capsule_radius
	_headroom_cast.target_position = Vector3.UP * (settings.standing_height - _height)
	_headroom_cast.force_shapecast_update()
	return not _headroom_cast.is_colliding()


## Height of a low step in front of the player that can be climbed, or 0.
## Godot's CharacterBody3D does not climb steps by itself.
func _step_up_height(motion: Vector3) -> float:
	if not is_on_floor() or motion.is_zero_approx():
		return 0.0
	var blocked := KinematicCollision3D.new()
	if (
		not test_move(global_transform, motion, blocked)
		or blocked.get_normal().angle_to(Vector3.UP) <= floor_max_angle
	):
		return 0.0  # Free path, or a walkable slope that move_and_slide handles.
	var rise := Vector3.UP * settings.max_step_height
	var raised := global_transform.translated(rise)
	# Probe far enough ahead for the round bottom of the capsule to land on the step.
	var probe := motion.normalized() * maxf(motion.length(), settings.capsule_radius * 0.5)
	var landing := KinematicCollision3D.new()
	if (
		test_move(global_transform, rise)
		or test_move(raised, probe)
		or not test_move(raised.translated(probe), -rise, landing)
	):
		return 0.0  # Ceiling above, too high to climb, or nothing to stand on.
	if landing.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return 0.0
	return rise.y + landing.get_travel().y


func _update_height(delta: float) -> void:
	var target := PlayerMotion.height_for_gait(settings, _gait)
	if is_equal_approx(_height, target):
		return
	var rate := (
		(settings.standing_height - settings.crouch_height) / settings.crouch_transition_time
	)
	_apply_height(move_toward(_height, target, rate * delta))


func _apply_height(height: float) -> void:
	_height = height
	_capsule.height = height
	_collision.position.y = height * 0.5
	_head.position.y = height - settings.eye_offset


func _update_head_bob(speed: float, target_speed: float, delta: float) -> void:
	if is_on_floor():
		_bob_phase = fmod(
			_bob_phase + speed * delta * TAU * settings.head_bob_cycles_per_meter, TAU
		)
	var amount := clampf(speed / target_speed, 0.0, 1.0) if target_speed > 0.0 else 0.0
	var amplitude := PlayerMotion.head_bob_amplitude(settings, _gait) * amount
	_camera.position = PlayerMotion.head_bob_offset(_bob_phase, amplitude)
