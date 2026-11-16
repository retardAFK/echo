class_name Monster
extends CharacterBody3D
## The AI monster (spec S-003): a MonsterBrain decides, this body moves.
## Follows its patrol route on the navigation mesh at the brain's pace, and
## walks to the noises it hears (NoiseBus, walls included), chases the player
## once spotted and catches them on contact.

signal state_changed(state: MonsterBrain.State)
signal player_caught
## Which hunted it caught (S-010, T-100), emitted with player_caught.
signal hunted_caught(hunted: Node3D)

## Distance the chase target must move before the path is recomputed, in meters.
const RETARGET_DISTANCE := 0.5
const DOOR_SETTINGS := preload("res://game/data/door_settings.tres")
const CONE_SEGMENTS := 16
## Lift above the floor so the debug cone does not flicker against it.
const CONE_GROUND_OFFSET := 0.05

@export var settings: MonsterSettings
## Node whose Marker3D children are the patrol points, in order.
@export var patrol_route: Node3D
@export var start_index := 0
## The hunted it chases: the player, or the AI prey in simulated games
## (S-007, T-060). Anything with get_gait() and get_eye_position().
@export var player: Node3D
## Buildings whose noises it remembers (S-007, Q10).
@export var buildings: Array[Building] = []

## The other hunted (S-010, T-100). It chases the one it sees: when it loses
## sight of player, the nearest other in sight becomes player.
var others: Array[Node3D] = []
var brain: MonsterBrain
var catch_count := 0
var sees_player := false
## Rolls whether it opens a hiding spot after losing a chase (S-008, Q7).
var rng := RandomNumberGenerator.new()
## The hiding spot it is going to open, or the camera to smash or the
## terminal to switch off (S-018, T-268), or null.
var open_target: Node3D
## Its concentration gauge for the building scan (S-009, Q3, D-009).
var scan: ScanGauge
## Building it is scanning, or null.
var scan_target: Building
## Its last one-shot gesture: catching, crushing (S-011, T-127).
var gesture := BodyGesture.new()
## What its body shows: a gesture, else what its brain is doing.
var body_action: MonsterBody.Action:
	get = _get_action

var _vision_timer := 0.0
var _was_hidden := false
var _noise: MonsterNoise
## Time left standing still over a hunted it just caught (T-127).
var _still_left := 0.0
var _sabotage_left := 0.0
var _prison_left := 0.0
var _jamb := JambUnstick.new()

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body: MonsterBody = $Body


func _ready() -> void:
	add_to_group(Prison.MONSTERS_GROUP)  # The prison's clock stops near it (S-018).
	brain = MonsterBrain.new(settings)
	_noise = MonsterNoise.new(settings)
	brain.state_changed.connect(state_changed.emit)
	brain.chase_lost.connect(_on_chase_lost)
	brain.trace_lost.connect(_on_trace_lost)
	brain.scan_finished.connect(_end_scan)
	scan = ScanGauge.new(settings)
	rng.randomize()
	brain.set_patrol(get_patrol_points(), start_index)
	_agent.target_position = brain.target
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	_build_vision_cone()


## Position of the monster's ears, where it hears noises from.
func get_ear_position() -> Vector3:
	return global_position + Vector3.UP * settings.ear_height


## Where it sees from: its eyes are at its ears' height.
func get_eye_position() -> Vector3:
	return get_ear_position()


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


func _process(_delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_body.show_state(speed, body_action)


func _get_action() -> MonsterBody.Action:
	if gesture.kind != MonsterBody.Action.NONE:
		return gesture.kind as MonsterBody.Action
	return MonsterBody.action_for(brain.state)


## Values of its body: the length of its gestures.
func get_body_settings() -> MonsterBodySettings:
	return _body.settings


## Stays where it is for a time (seconds), the hunted it caught in its claws:
## no move, no catch (T-127).
func hold_still(duration: float) -> void:
	_still_left = duration
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	gesture.update(delta)
	if _still_left > 0.0:
		_still_left -= delta
		return
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
	scan.update(delta)
	if scan_target != null and not scan.active:
		brain.stop_scan()  # The gauge ran dry.
	if scan_target != null and brain.state != MonsterBrain.State.SCAN:
		_end_scan()  # Spotted the hunted, or heard something.
	_update_opening(delta, arrived)
	_look_for_sabotage(delta)
	_visit_prison(delta)
	if _agent.target_position.distance_to(brain.target) > RETARGET_DISTANCE:
		_agent.target_position = brain.target
	var before := global_position
	_move(delta)
	_make_noise(delta, before)
	if Decoy.crush_near(get_tree(), global_position, settings.catch_distance) > 0:  # S-008, Q4.
		gesture.play(MonsterBody.Action.CRUSH, _body.settings.crush_time)
	for hunted in get_targets():
		if (
			not HidingSpot.is_hidden(hunted)
			and brain.is_catch(hunted.global_position - global_position)
		):
			catch_count += 1
			gesture.play(MonsterBody.Action.CATCH, _body.settings.catch_time)
			hunted_caught.emit(hunted)
			player_caught.emit()
			break


## Every hunted it may catch: player first, then the others still there.
func get_targets() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for hunted: Node3D in [player] + others:
		if hunted != null and is_instance_valid(hunted) and hunted not in found:
			found.append(hunted)
	return found


## Stops chasing a hunted for good (caught and out of the game).
func forget(hunted: Node3D) -> void:
	others.erase(hunted)
	if hunted == player:
		player = others.pop_front() if not others.is_empty() else null
		sees_player = false


## Chases a hunted again (freed by a teammate, S-010, T-107).
func add_target(hunted: Node3D) -> void:
	if hunted in get_targets():
		return
	if player == null:
		player = hunted
	else:
		others.append(hunted)


## Leaves a hunted it just captured (T-107): back to its watch, or on patrol
## from the point farthest from there, walking, so that a teammate may come
## to free it.
func walk_away(from: Vector3) -> void:
	sees_player = false
	brain.let_go(MonsterBrain.farthest_index(get_patrol_points(), from))
	_agent.target_position = brain.target


## Footsteps by distance walked, at the pace's range, and a short-range breath.
func _make_noise(delta: float, before: Vector3) -> void:
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_noise.update(delta, moved, brain.get_pace(), global_position, get_ear_position(), self)


func _update_sight(delta: float) -> void:
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer = settings.vision_interval
	var eye := get_ear_position()
	var target: Vector3 = player.get_eye_position()
	var hidden := HidingSpot.is_hidden(player)
	if hidden and not _was_hidden and sees_player:
		go_open(player.get("hiding_in"))  # It saw the hunted get in (S-008, Q7).
	_was_hidden = hidden
	sees_player = _can_see(player)
	if hidden and sees_player and open_target == null:
		go_open(player.get("hiding_in"))  # Seen behind its curtain (S-016, Q6).
	if sees_player or others.is_empty():
		return
	# Lost sight of it: the nearest other hunted in sight becomes the target.
	var nearest: Node3D = null
	for hunted in get_targets():
		if hunted == player or not _can_see(hunted):
			continue
		if nearest == null or _closer(hunted, nearest):
			nearest = hunted
	if nearest != null:
		others.erase(nearest)
		others.append(player)
		player = nearest
		sees_player = true
		_was_hidden = false


func _can_see(hunted: Node3D) -> bool:
	var eye := get_ear_position()
	var target: Vector3 = hunted.get_eye_position()
	if HidingSpot.is_revealed(hunted, eye, -global_basis.z):
		return true  # Right beside a makeshift spot, facing it (S-016, Q6).
	return (
		not HidingSpot.is_hidden(hunted)  # Hidden: never seen (S-008, Q6).
		and MonsterVision.in_view_cone(eye, -global_basis.z, target, settings)
		and MonsterVision.has_line_of_sight(get_world_3d().direct_space_state, eye, target)
	)


func _closer(a: Node3D, b: Node3D) -> bool:
	return (
		global_position.distance_squared_to(a.global_position)
		< global_position.distance_squared_to(b.global_position)
	)


## Goes to open a hiding spot and opens it (S-008, Q7).
func go_open(spot: HidingSpot) -> void:
	if spot == null:
		return
	open_target = spot
	brain.go_open(spot.get_exit_point())
	_agent.target_position = brain.target


## At the hiding spot, it faces it and holds it open like a player would: the
## same time, the same creak. Whoever is inside is caught.
func _update_opening(delta: float, arrived: bool) -> void:
	if open_target == null:
		return
	if brain.state != MonsterBrain.State.OPEN:
		open_target.release(self)
		open_target = null  # Something more urgent: a chase.
		return
	if not (open_target is HidingSpot) and _sabotage_done(open_target):
		open_target = null
		brain.done_opening()
		return
	if not brain.is_opening(arrived):
		return
	var at := Vector3(
		open_target.global_position.x, global_position.y, open_target.global_position.z
	)
	if at.distance_to(global_position) > 0.01:
		look_at(at, Vector3.UP)
	if not (open_target is HidingSpot):
		open_target.hold(self, delta)  # Smashes or switches off once held long enough.
		return
	if open_target.hold(self, delta):
		open_target.release(self)
		open_target = null
		brain.done_opening()


## Goes to smash a lit camera or switch off a terminal in use (S-018, T-268).
func go_sabotage(target: Node3D) -> void:
	open_target = target
	var at := target.global_position
	if target is Terminal:
		at = (target as Terminal).seat_point()
	brain.go_open(at)
	_agent.target_position = brain.target


func _sabotage_done(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return true
	if target is SecurityCamera:
		return (target as SecurityCamera).broken
	if target is Terminal:
		return not (target as Terminal).is_on()
	return true


## Now and then on its rounds, a lit camera or a terminal in use (or
## downloading) in sight draws it (S-018, T-268).
func _look_for_sabotage(delta: float) -> void:
	_sabotage_left -= delta
	if _sabotage_left > 0.0 or open_target != null:
		return
	_sabotage_left = settings.sabotage_interval
	if brain.state not in [MonsterBrain.State.PATROL, MonsterBrain.State.SEARCH]:
		return
	var eye := get_ear_position()
	var space := get_world_3d().direct_space_state
	for camera: SecurityCamera in get_tree().get_nodes_in_group(SecurityCamera.GROUP):
		if camera.broken or not camera.is_led_lit():
			continue
		if _in_sight(eye, camera.global_position, space):
			go_sabotage(camera)
			return
	var quests := Quests.of(self)
	for terminal: Terminal in get_tree().get_nodes_in_group(Terminal.GROUP):
		if not terminal.is_on():
			continue
		var busy := terminal.is_in_use()
		if quests != null and terminal == quests.download_terminal:
			busy = busy or quests.download_ratio() >= 0.0
		if busy and _in_sight(eye, terminal.global_position + Vector3.UP, space):
			go_sabotage(terminal)
			return


func _in_sight(eye: Vector3, at: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	return (
		eye.distance_to(at) <= settings.sabotage_range
		and MonsterVision.has_line_of_sight(space, eye, at)
	)


## While someone waits in a cage, it comes back by the prison now and then
## (S-018, T-268), as for a noise heard in a building.
func _visit_prison(delta: float) -> void:
	_prison_left -= delta
	if _prison_left > 0.0:
		return
	_prison_left = settings.prison_visit_interval
	var prison := Prison.of(get_parent())
	if prison != null and prison.cages.any(func(cage: Cage) -> bool: return cage.is_occupied()):
		brain.remember(prison.global_position)


## Lost the chase: it may open the hiding spot nearest to where it last saw
## the hunted, one time out of two (S-008, Q7).
func _on_chase_lost(last_seen: Vector3) -> void:
	var spot := HidingSpot.nearest(get_tree(), last_seen, settings.search_hide_radius)
	if spot != null and rng.randf() < settings.search_open_chance:
		go_open(spot)


## It found nobody where it looked (S-009, Q3): if a building lies close by,
## it stops and scans it, when the gauge and the cooldown allow it.
func _on_trace_lost(at: Vector3) -> void:
	var building := nearest_building(at, settings.ai_scan_radius)
	if building == null or not brain.can_scan(building, scan.can_start()):
		return
	if not scan.start():
		return
	scan_target = building
	building.scanned = true  # Its lights flicker: the hunted's warning.
	brain.start_scan(building, global_position)
	var center := building.get_box_transform().origin
	center.y = global_position.y
	if center.distance_to(global_position) > 0.01:
		look_at(center, Vector3.UP)


## The building nearest to a position, within a distance, or null.
func nearest_building(at: Vector3, radius: float) -> Building:
	var best: Building = null
	var best_distance := radius
	for building in buildings:
		var d := building.distance_to(at)
		if d <= best_distance:
			best = building
			best_distance = d
	return best


## True if the scan reveals this noise: listening, and it comes from inside the
## scanned building, however faint (same rule as the playable monster).
func scan_reveals(event: NoiseEvent) -> bool:
	return scan_target != null and scan.is_listening() and scan_target.contains(event.position)


func _end_scan() -> void:
	scan.stop()
	if scan_target == null:
		return
	var building := scan_target
	scan_target = null
	building.scanned = false


## Guards the exit tunnel from now on (S-007, Q4): the siren told it where the
## hunted is going.
func guard_exit(points: Array[Vector3]) -> void:
	brain.guard(points)
	_agent.target_position = brain.target


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.source == self or not is_inside_tree():
		return  # Its own noise, or removed from the map (monster role).
	if event.source is Door and (event.source as Door).last_user == self:
		return  # A door it opened itself (S-016).
	if scan_reveals(event):
		brain.remember(event.position)
		brain.hear(event.position)  # Even a faint one, like a breath (D-009).
		return
	if event.type == NoiseEvent.Type.SIREN and brain.guarding:
		return  # Heard: it already left for the tunnel.
	if event.type == NoiseEvent.Type.CALL:
		return  # Its own prisoner calling: nothing new (T-107).
	if NoiseBus.can_hear(event, get_ear_position()):
		brain.hear(event.position)
		for building in buildings:
			if building.contains(event.position):
				brain.remember(event.position)
				break


func _move(delta: float) -> void:
	var horizontal := Vector3.ZERO
	var scanning := brain.state == MonsterBrain.State.SCAN
	if brain.lingering:
		rotate_y(deg_to_rad(settings.look_around_speed) * delta)
	if not brain.lingering and not scanning and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var direction := next - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			horizontal = direction * MonsterBrain.speed_for(brain.get_pace(), settings)
			look_at(global_position + direction, Vector3.UP)
			_open_door(direction)
	if global_position.distance_to(_agent.target_position) > JambUnstick.GOAL_CLEARANCE:
		horizontal = _jamb.update(self, horizontal, delta)  # Not at its goal: a jamb.
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()


## A closed door on its way: smashed on the run, opened otherwise (S-016, Q2).
func _open_door(direction: Vector3) -> void:
	var door := Door.closed_ahead(get_tree(), global_position, direction, DOOR_SETTINGS.ai_reach)
	if door == null:
		return
	if brain.get_pace() == MonsterBrain.Pace.RUN:
		door.smash(self)
	else:
		door.open_by(self)


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
