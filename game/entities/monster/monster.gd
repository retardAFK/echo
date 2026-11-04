class_name Monster
extends CharacterBody3D
## The AI monster (spec S-003): a MonsterBrain decides, this body moves.
## Follows its patrol route on the navigation mesh at the brain's pace, and
## walks to the noises it hears (NoiseBus, walls included), chases the player
## once spotted and catches them on contact.

signal state_changed(state: MonsterBrain.State)
signal player_caught

## Distance the chase target must move before the path is recomputed, in meters.
const RETARGET_DISTANCE := 0.5
const CONE_SEGMENTS := 16
## Lift above the floor so the debug cone does not flicker against it.
const CONE_GROUND_OFFSET := 0.05

@export var settings: MonsterSettings
## Node whose Marker3D children are the patrol points, in order.
@export var patrol_route: Node3D
@export var start_index := 0
@export var player: Player

var brain: MonsterBrain
var catch_count := 0
var sees_player := false

var _vision_timer := 0.0
var _step_distance := 0.0
var _breath_timer := 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	brain = MonsterBrain.new(settings)
	brain.state_changed.connect(state_changed.emit)
	brain.set_patrol(get_patrol_points(), start_index)
	_agent.target_position = brain.target
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	_build_vision_cone()


## Position of the monster's ears, where it hears noises from.
func get_ear_position() -> Vector3:
	return global_position + Vector3.UP * settings.ear_height


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


## Sends the monster back on patrol, at the point farthest from a position.
func reset_to_patrol(away_from: Vector3) -> void:
	var points := get_patrol_points()
	var index := MonsterBrain.farthest_index(points, away_from)
	global_position = points[index]
	velocity = Vector3.ZERO
	brain.spot_level = 0.0
	sees_player = false
	brain.set_patrol(points, index)
	_agent.target_position = brain.target


func _physics_process(delta: float) -> void:
	var arrived := _agent.is_navigation_finished()
	var player_position := Vector3.ZERO
	var distance := 0.0
	var crouched := false
	if player != null:
		player_position = player.global_position
		distance = global_position.distance_to(player_position)
		crouched = player.get_gait() == PlayerMotion.Gait.CROUCH
		_update_sight(delta)
	brain.update(delta, sees_player, player_position, distance, crouched, arrived)
	if _agent.target_position.distance_to(brain.target) > RETARGET_DISTANCE:
		_agent.target_position = brain.target
	var before := global_position
	_move(delta)
	_make_noise(delta, before)
	if player != null and brain.is_catch_distance(_flat_distance(player_position)):
		catch_count += 1
		player_caught.emit()


## Footsteps by distance walked, at the pace's range, and a short-range breath.
func _make_noise(delta: float, before: Vector3) -> void:
	_step_distance += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if _step_distance >= settings.stride:
		_step_distance = fmod(_step_distance, settings.stride)
		var step_range := MonsterBrain.noise_range_for(brain.get_pace(), settings)
		if step_range > 0.0:
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, global_position, step_range, self)
	_breath_timer += delta
	if _breath_timer >= settings.breath_interval:
		_breath_timer = 0.0
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, get_ear_position(), settings.breath_range, self)


func _update_sight(delta: float) -> void:
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer = settings.vision_interval
	var eye := get_ear_position()
	var target := player.get_eye_position()
	sees_player = (
		MonsterVision.in_view_cone(eye, -global_basis.z, target, settings)
		and MonsterVision.has_line_of_sight(get_world_3d().direct_space_state, eye, target)
	)


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.source == self:
		return
	if NoiseBus.can_hear(event, get_ear_position()):
		brain.hear(event.position)


func _move(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if brain.lingering:
		rotate_y(deg_to_rad(settings.look_around_speed) * delta)
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


## Outline of the field of view on the ground, shown with F4 (noise debug).
func _build_vision_cone() -> void:
	var half := deg_to_rad(settings.vision_angle / 2.0)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3.ZERO)
	for i in CONE_SEGMENTS + 1:
		var angle := lerpf(-half, half, float(i) / CONE_SEGMENTS)
		mesh.surface_add_vertex(Vector3(sin(angle), 0.0, -cos(angle)) * settings.vision_range)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = settings.debug_cone_color
	var cone := MeshInstance3D.new()
	cone.name = "VisionCone"
	cone.mesh = mesh
	cone.material_override = material
	cone.position.y = CONE_GROUND_OFFSET
	cone.visible = false
	cone.add_to_group(NoiseDebug.DEBUG_GROUP)
	add_child(cone)
