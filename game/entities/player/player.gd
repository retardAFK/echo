class_name Player
extends CharacterBody3D
## First-person player controller (spec S-001).
## Movement math lives in PlayerMotion, tunable values in PlayerSettings.

@export var settings: PlayerSettings

var _gait := PlayerMotion.Gait.WALK
var _pitch := 0.0
var _capsule: CapsuleShape3D

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head


func _ready() -> void:
	# Each player owns its capsule, so resizing it never touches another instance.
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_capsule.radius = settings.capsule_radius
	_apply_height(settings.standing_height)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only allow pointer capture right after a user gesture.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.screen_relative)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target_speed := PlayerMotion.speed_for_gait(settings, _gait)
	var target := PlayerMotion.wish_direction(input, rotation.y) * target_speed
	var horizontal := PlayerMotion.approach_velocity(
		Vector3(velocity.x, 0.0, velocity.z), target, settings, delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


## Turns the body (yaw) and the head (pitch) from a mouse movement in screen pixels.
func look(relative: Vector2) -> void:
	var sensitivity := deg_to_rad(settings.mouse_sensitivity)
	rotate_y(-relative.x * sensitivity)
	_pitch = PlayerMotion.clamp_pitch(_pitch - relative.y * sensitivity, settings)
	_head.rotation.x = _pitch


func get_pitch() -> float:
	return _pitch


func _apply_height(height: float) -> void:
	_capsule.height = height
	_collision.position.y = height * 0.5
	_head.position.y = height - settings.eye_offset
