class_name Monster
extends CharacterBody3D
## The AI monster (spec S-003): a MonsterBrain decides, this body moves.
## Follows its patrol route on the navigation mesh at the brain's pace.

signal state_changed(state: MonsterBrain.State)

@export var settings: MonsterSettings
## Node whose Marker3D children are the patrol points, in order.
@export var patrol_route: Node3D
@export var start_index := 0

var brain: MonsterBrain

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	brain = MonsterBrain.new(settings)
	brain.state_changed.connect(state_changed.emit)
	brain.set_patrol(get_patrol_points(), start_index)
	_agent.target_position = brain.target


func get_patrol_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if patrol_route == null:
		return points
	for child in patrol_route.get_children():
		if child is Node3D:
			points.append(child.global_position)
	return points


func get_state() -> MonsterBrain.State:
	return brain.state


func _physics_process(delta: float) -> void:
	var arrived := _agent.is_navigation_finished()
	brain.update(delta, false, Vector3.ZERO, 0.0, false, arrived)
	if not _agent.target_position.is_equal_approx(brain.target):
		_agent.target_position = brain.target
	_move(delta)


func _move(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if not brain.lingering and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var direction := next - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			horizontal = direction * MonsterBrain.speed_for(brain.get_pace(), settings)
			look_at(global_position + direction, Vector3.UP)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
