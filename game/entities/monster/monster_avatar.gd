class_name MonsterAvatar
extends CharacterBody3D
## The playable monster (spec S-004, Q6): first person, eyes at ear height,
## mouse and ZQSD like the hunted. Walks by default, runs with the sprint key,
## prowls without a sound with the crouch key (toggle). Its footsteps and
## breath go through NoiseBus exactly like the AI monster's (D-009).
## Holding the scan button while aiming at a building scans it (Q3): the
## monster stands still and, after a short concentration, hears every noise
## inside, whatever its range, until the gauge runs out or the button is released.

signal scan_started(building: Building)
signal scan_ended(building: Building)

@export var settings: MonsterSettings
## Mouse sensitivity, look limit and acceleration are shared with the hunted.
@export var controls: PlayerSettings

var catch_count := 0
var scan: ScanGauge
## Building being scanned, or null.
var scan_target: Building

var _pace := MonsterBrain.Pace.WALK
var _prowling := false
var _pitch := 0.0
var _noise: MonsterNoise

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


## Pace from the controls: prowling wins over running, standing still walks.
static func resolve_pace(prowling: bool, sprinting: bool, moving: bool) -> MonsterBrain.Pace:
	if prowling:
		return MonsterBrain.Pace.PROWL
	if sprinting and moving:
		return MonsterBrain.Pace.RUN
	return MonsterBrain.Pace.WALK


func _ready() -> void:
	_noise = MonsterNoise.new(settings)
	scan = ScanGauge.new(settings)
	_head.position.y = settings.ear_height
	_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crouch"):
		toggle_prowl()
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only allow pointer capture right after a user gesture.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.screen_relative)


func _physics_process(delta: float) -> void:
	update_scan(delta, Input.is_action_pressed("scan"))
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move(input, Input.is_action_pressed("sprint"), delta)


## Moves one physics step from a 2D input (x = right, y = back).
func move(input: Vector2, sprinting: bool, delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if scan.active:
		input = Vector2.ZERO  # The monster stands still while it scans.
	_pace = resolve_pace(_prowling, sprinting, not input.is_zero_approx())
	var target := PlayerMotion.wish_direction(input, rotation.y) * get_speed()
	var horizontal := PlayerMotion.approach_velocity(
		Vector3(velocity.x, 0.0, velocity.z), target, controls, delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_noise.update(delta, moved, _pace, global_position, get_ear_position(), self)


## Turns the body (yaw) and the head (pitch) from a mouse movement in screen pixels.
func look(relative: Vector2) -> void:
	var sensitivity := deg_to_rad(controls.mouse_sensitivity)
	rotate_y(-relative.x * sensitivity)
	_pitch = PlayerMotion.clamp_pitch(_pitch - relative.y * sensitivity, controls)
	_head.rotation.x = _pitch


## Starts, keeps or stops the scan from the scan button, and drains or recharges the gauge.
func update_scan(delta: float, holding: bool) -> void:
	if holding and not scan.active:
		var building := aim_building()
		if building != null and scan.start():
			scan_target = building
			building.scanned = true
			scan_started.emit(building)
	elif not holding and scan.active:
		scan.stop()
	scan.update(delta)
	if not scan.active and scan_target != null:
		var building := scan_target
		scan_target = null
		building.scanned = false
		scan_ended.emit(building)


## The building in the middle of the view, within scan range, or null.
func aim_building() -> Building:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * settings.scan_max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, Building.SCAN_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Building


## True if the scan reveals this noise: listening, and it comes from inside the building.
func scan_reveals(event: NoiseEvent) -> bool:
	return (
		scan.is_listening()
		and scan_target != null
		and event.source != self
		and scan_target.contains(event.position)
	)


func toggle_prowl() -> void:
	_prowling = not _prowling


func get_pace() -> MonsterBrain.Pace:
	return _pace


## Target speed of the current pace, in m/s.
func get_speed() -> float:
	return MonsterBrain.speed_for(_pace, settings)


func get_ear_position() -> Vector3:
	return global_position + Vector3.UP * settings.ear_height


## Same as the ears: what the prey tries to see and where the player listens from.
func get_eye_position() -> Vector3:
	return get_ear_position()


## Where the camera looks, for aiming the building scan (T-023).
func get_camera() -> Camera3D:
	return _camera
