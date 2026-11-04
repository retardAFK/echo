class_name Prey
extends CharacterBody3D
## The AI prey the monster hunts in solo tests (spec S-004, Q4): a PreyBrain
## decides, this body moves on the navigation mesh at the hunted's speeds and
## makes the hunted's footstep noises (FootstepEmitter). It hears the monster
## through NoiseBus and sees it within its sight range.

signal state_changed(state: PreyBrain.State)

## Distance the target must move before the path is recomputed, in meters.
const RETARGET_DISTANCE := 0.5

@export var settings: PreySettings
## Speeds of the hunted (S-001).
@export var motion: PlayerSettings
## Node whose Marker3D children are the points the prey wanders between.
@export var wander_route: Node3D
## Node whose Marker3D children are the hiding spots.
@export var hiding_spots: Node3D
## The playable monster, with get_eye_position().
@export var monster: Node3D

var brain: PreyBrain
var sees_monster := false

var _heard_monster := false
var _vision_timer := 0.0
var _stuck_left := 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	brain = PreyBrain.new(settings, hash(name))
	brain.state_changed.connect(state_changed.emit)
	brain.set_points(markers_of(wander_route), markers_of(hiding_spots))
	_agent.target_position = brain.target
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


static func markers_of(parent: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if parent == null:
		return points
	for child in parent.get_children():
		if child is Node3D:
			points.append(child.global_position)
	return points


func get_state() -> PreyBrain.State:
	return brain.state


func get_gait() -> PlayerMotion.Gait:
	return brain.get_gait()


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * settings.ear_height


func _physics_process(delta: float) -> void:
	var threat := Vector3.ZERO
	if monster != null:
		threat = monster.global_position
		_update_sight(delta)
	var alarm := sees_monster or _heard_monster
	_heard_monster = false
	var arrived := _agent.is_navigation_finished()
	brain.update(delta, alarm, threat, arrived, false)
	if _agent.target_position.distance_to(brain.target) > RETARGET_DISTANCE:
		_agent.target_position = brain.target
		_stuck_left = settings.stuck_time
	var before := global_position
	_move(delta)
	_check_stuck(delta, before)


## Gives up a target it cannot reach: blocked against a wall, or off the mesh.
func _check_stuck(delta: float, before: Vector3) -> void:
	var trying := not brain.is_still(_agent.is_navigation_finished())
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var expected := PlayerMotion.speed_for_gait(motion, brain.get_gait()) * delta
	if not trying or moved > expected * 0.25:
		_stuck_left = settings.stuck_time
		return
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		_stuck_left = settings.stuck_time
		brain.give_up()


func _update_sight(delta: float) -> void:
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer = settings.vision_interval
	sees_monster = can_see_monster()


## Whether the monster is in the prey's field of view, in range, and not behind a wall.
func can_see_monster() -> bool:
	var eye := get_eye_position()
	var target: Vector3 = monster.get_eye_position()
	var to_target := target - eye
	if to_target.length() > settings.sight_range:
		return false
	var forward := -global_basis.z
	var angle := rad_to_deg(
		Vector3(forward.x, 0.0, forward.z).angle_to(Vector3(to_target.x, 0.0, to_target.z))
	)
	return (
		angle <= settings.vision_angle / 2.0
		and MonsterVision.has_line_of_sight(get_world_3d().direct_space_state, eye, target)
	)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.source == self or event.source != monster:
		return
	if NoiseBus.can_hear(event, get_eye_position()):
		_heard_monster = true


func _move(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if not brain.is_still(_agent.is_navigation_finished()) and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var direction := next - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			horizontal = direction * PlayerMotion.speed_for_gait(motion, brain.get_gait())
			look_at(global_position + direction, Vector3.UP)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
