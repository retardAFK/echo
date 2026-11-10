class_name Prey
extends CharacterBody3D
## The AI prey the monster hunts in solo tests (spec S-004, Q4): a PreyBrain
## decides, this body moves on the navigation mesh at the hunted's speeds and
## makes the hunted's footstep noises (FootstepEmitter). It hears the monster
## through NoiseBus and sees it within its sight range. Out of breath after a
## run, it pants faintly (only the scan reveals it). When a building it is in
## is scanned, it notices the flickering lights one time out of two and
## freezes until the scan ends (Q5).
## In the game loop (S-007, Q7) it looks for the fuses, repairs the transformer
## and runs for the exit, holding "interact" like the hunted (HoldInteraction).

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
## Buildings whose scans the prey may notice.
@export var buildings: Array[Building] = []

var brain: PreyBrain
var sees_monster := false
## The game it plays (S-007), null outside the game loop.
var game_loop: GameLoop

var _heard_monster := false
var _vision_timer := 0.0
var _stuck_left := 0.0
var _breath_timer := 0.0
## Game loop (S-007): the boxes in visiting order, and what it holds on.
var _boxes: Array[FuseBox] = []
var _hold := HoldInteraction.new()
## Building whose scan the prey noticed, or null.
var _warned_by: Building
var _rng := RandomNumberGenerator.new()

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_rng.seed = hash(name)
	brain = PreyBrain.new(settings, _rng.randi())
	brain.state_changed.connect(state_changed.emit)
	brain.set_points(markers_of(wander_route), markers_of(hiding_spots))
	_agent.target_position = brain.target
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	for building in buildings:
		building.scan_changed.connect(_on_scan_changed.bind(building))


static func markers_of(parent: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if parent == null:
		return points
	for child in parent.get_children():
		if child is Node3D:
			points.append(child.global_position)
	return points


## Plays the game loop: visits the buildings one by one, nearest first, and the
## boxes of each building nearest first (S-007, Q7). A seed other than 0 makes
## its choices differ from one game to the next.
func start_loop(loop: GameLoop, boxes: Array[FuseBox], rng_seed := 0) -> void:
	game_loop = loop
	if rng_seed != 0:
		_rng.seed = rng_seed
		brain.reseed(_rng.randi())
	_boxes = order_boxes(boxes, global_position)
	var slots: Array[Vector3] = []
	for box in _boxes:
		slots.append(box.get_approach_point())
	var transformer := loop.transformer
	var side := transformer.global_basis.z * (transformer.half_size.y + 0.8)
	var exit := loop.exit_zone.global_position
	exit.y = global_position.y
	brain.set_loop(slots, transformer.global_position + side, exit)
	_agent.target_position = brain.target


## Visiting order: the nearest building first, then the nearest one from there;
## inside a building, the nearest box from the last one.
static func order_boxes(boxes: Array[FuseBox], from: Vector3) -> Array[FuseBox]:
	var by_building := {}
	for box in boxes:
		if not by_building.has(box.building_name):
			by_building[box.building_name] = []
		by_building[box.building_name].append(box)
	var ordered: Array[FuseBox] = []
	var at := from
	while not by_building.is_empty():
		var best_name := ""
		var best := INF
		for building_name: String in by_building:
			for box: FuseBox in by_building[building_name]:
				var distance := at.distance_to(box.global_position)
				if distance < best:
					best = distance
					best_name = building_name
		var left: Array = by_building[best_name]
		by_building.erase(best_name)
		while not left.is_empty():
			var nearest := 0
			for i in left.size():
				if (
					at.distance_to(left[i].global_position)
					< at.distance_to(left[nearest].global_position)
				):
					nearest = i
			var box: FuseBox = left.pop_at(nearest)
			ordered.append(box)
			at = box.global_position
	return ordered


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
	brain.update(delta, alarm, threat, arrived, is_warned())
	if game_loop != null:
		_play_loop(delta, arrived)
	if _agent.target_position.distance_to(brain.target) > RETARGET_DISTANCE:
		_agent.target_position = brain.target
		_stuck_left = settings.stuck_time
	var before := global_position
	_move(delta)
	_check_stuck(delta, before)
	_pant(delta)


## The loop's part of a frame: decides at a box or the transformer, and holds
## "interact" while it works.
func _play_loop(delta: float, arrived: bool) -> void:
	var work_on: Node = null
	match brain.state:
		PreyBrain.State.SEARCH:
			if arrived and _agent.target_position.distance_to(brain.target) <= RETARGET_DISTANCE:
				_arrive()
		PreyBrain.State.WORK:
			work_on = _work_target()
	_hold.update(self, work_on, work_on != null, delta)
	if brain.state == PreyBrain.State.WORK and _work_finished():
		var rules := game_loop.rules
		brain.work_done(rules.found(), rules.fuse_count, rules.is_repaired())


## It reached the slot or the transformer it was heading to.
func _arrive() -> void:
	if brain.goal == PreyBrain.Goal.REPAIR:
		brain.start_work()
	elif _boxes[brain.slot_index].has_fuse:
		brain.start_work()  # It sees the red LED.
	else:
		brain.next_slot()


func _work_target() -> Node:
	if brain.goal == PreyBrain.Goal.REPAIR:
		return game_loop.transformer
	return _boxes[brain.slot_index]


func _work_finished() -> bool:
	if brain.goal == PreyBrain.Goal.REPAIR:
		return game_loop.rules.carried == 0 or game_loop.rules.is_repaired()
	return not _boxes[brain.slot_index].has_fuse


## True while the prey noticed a scan and the scan is still on.
func is_warned() -> bool:
	return _warned_by != null


## Back to wandering from a wander point, rested (after a catch).
func respawn(at: Vector3, index: int) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_warned_by = null
	_breath_timer = 0.0
	brain.reset(index)
	_agent.target_position = brain.target


## The faint panting of an out of breath prey, at its mouth.
func _pant(delta: float) -> void:
	if not brain.is_breathless():
		_breath_timer = 0.0
		return
	_breath_timer += delta
	if _breath_timer >= settings.breath_interval:
		_breath_timer = 0.0
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, get_eye_position(), settings.breath_range, self)


func _on_scan_changed(is_scanned: bool, building: Building) -> void:
	if not is_scanned:
		if building == _warned_by:
			_warned_by = null
		return
	if building.contains(get_eye_position()) and _rng.randf() < settings.scan_notice_chance:
		_warned_by = building


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
