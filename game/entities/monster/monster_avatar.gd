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
## The scan button was pressed but no scan started (T-086), and why.
signal scan_missed(reason: ScanMiss)

## Why a scan did not start: nothing scannable aimed at, a scannable building
## aimed at but too far, or a gauge too low.
enum ScanMiss { NOTHING, TOO_FAR, GAUGE_LOW }

## A wall this close to a building's box (its facade may stand a little
## outside the box) belongs to it, for aim_far_building().
const FAR_AIM_WALL_MARGIN := 4.0
## Length of the gestures the hunted see (S-011, T-127).
const BODY_SETTINGS := preload("res://game/data/monster_body_settings.tres")

@export var settings: MonsterSettings
## Mouse sensitivity, look limit and acceleration are shared with the hunted.
@export var controls: PlayerSettings

var catch_count := 0
var scan: ScanGauge
## Building being scanned, or null.
var scan_target: Building
## Scannable building in the middle of the view, within scan range, or null.
## Updated every physics frame, for the reticle (T-086).
var aimed_building: Building
## Scannable building in the middle of the view beyond scan range (up to
## scan_hint_distance, no wall in front), when aimed_building is null.
var far_building: Building
## What the player asks this frame (S-010, T-106): from the keyboard and
## mouse when local_controls is on, else set by the network.
var commands := PlayerCommands.new()
## Whether this machine's keyboard and mouse drive the monster.
var local_controls := true
## Online client (S-010, T-099): the room opens hiding spots and crushes alarm
## clocks; here the monster moves, scans for its own screen and shows the
## progress the room says.
var mirror_world := false
var remote_hold_ratio := 0.0
## Its last one-shot gesture, as the hunted see it: catching, crushing (T-127).
var gesture := BodyGesture.new()

var _pace := MonsterBrain.Pace.WALK
var _prowling := false
var _pitch := 0.0
var _noise: MonsterNoise
var _hold := HoldInteraction.new()
var _was_holding := false
var _controls: LocalControls

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
	_apply_view_settings("")
	Settings.changed.connect(_apply_view_settings)
	if local_controls:
		_controls = LocalControls.new()
		_controls.commands = commands
		add_child(_controls)
		if NetSession.mode == NetSession.Mode.CLIENT:
			NetSession.local_commands = commands  # Sent to the room (S-010, T-095).


func _physics_process(delta: float) -> void:
	if _controls != null:
		_controls.fill()
	else:
		set_look(commands.yaw, commands.pitch)  # Played from another machine (T-097).
	gesture.update(delta)
	apply_actions()
	update_aim()
	update_scan(delta, commands.scan)
	move(commands.move, commands.sprint, delta)
	if not mirror_world:
		_hold.update(self, get_interactable(), commands.interact, delta)


## Applies the one-shot actions queued in the commands (S-010, T-106). The
## monster only prowls; it has no bottles, alarm clocks or pickups.
func apply_actions() -> void:
	for action in commands.take_actions():
		if action == PlayerCommands.Action.CROUCH:
			toggle_prowl()


## The hiding spot in reach in front of the crosshair, that it can open by
## holding "interact" (S-008, Q7), or null.
func get_interactable() -> Node:
	var best: Node = null
	var best_distance := INF
	var forward := -_camera.global_basis.z
	var aim := Vector2(forward.x, forward.z).normalized()
	for node in get_tree().get_nodes_in_group(HidingSpot.GROUP):
		var spot := node as HidingSpot
		if not spot.can_interact(global_position):
			continue
		var gap := spot.global_position - global_position
		var flat := Vector2(gap.x, gap.z)
		if flat.length() > 0.01 and aim.dot(flat.normalized()) < cos(Player.AIM_ANGLE):
			continue
		if flat.length() < best_distance:
			best = spot
			best_distance = flat.length()
	return best


## Progress of the hiding spot it is opening, from 0 to 1.
func get_hold_ratio() -> float:
	return remote_hold_ratio if mirror_world else _hold.get_ratio()


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
	if not mirror_world and Decoy.crush_near(get_tree(), global_position, settings.catch_distance):
		gesture.play(MonsterBody.Action.CRUSH, BODY_SETTINGS.crush_time)  # S-008, Q4.


## What the hunted see it do (S-011, T-127): a gesture, else scanning, else
## opening a hiding spot (holding "interact" on it).
func get_action() -> MonsterBody.Action:
	if gesture.kind != MonsterBody.Action.NONE:
		return gesture.kind as MonsterBody.Action
	if scan.active:
		return MonsterBody.Action.SCAN
	if _hold.holding:
		return MonsterBody.Action.OPEN
	return MonsterBody.Action.NONE


## Field of view from the options (S-013, T-163).
func _apply_view_settings(_key: String) -> void:
	_camera.fov = float(Settings.get_value("fov"))


## Turns the body (yaw) and the head (pitch) from a mouse movement in screen pixels.
func look(relative: Vector2) -> void:
	var sensitivity := deg_to_rad(controls.mouse_sensitivity)
	rotate_y(-relative.x * sensitivity)
	_pitch = PlayerMotion.clamp_pitch(_pitch - relative.y * sensitivity, controls)
	_head.rotation.x = _pitch


## Turns the body and the head to a yaw and pitch sent by another machine.
func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = PlayerMotion.clamp_pitch(pitch, controls)
	_head.rotation.x = _pitch


## Starts, keeps or stops the scan from the scan button, and drains or recharges the gauge.
func update_scan(delta: float, holding: bool) -> void:
	if holding and not scan.active:
		var building := aim_building()
		if building != null and scan.start():
			scan_target = building
			building.scanned = true
			scan_started.emit(building)
		elif not _was_holding:
			scan_missed.emit(miss_reason(building))
	elif not holding and scan.active:
		scan.stop()
	scan.update(delta)
	_was_holding = holding
	if not scan.active and scan_target != null:
		var building := scan_target
		scan_target = null
		building.scanned = false
		scan_ended.emit(building)


## What the reticle shows: the building aimed at in range, or else the one
## aimed at too far away.
func update_aim() -> void:
	aimed_building = aim_building()
	far_building = null if aimed_building != null else aim_far_building()


## Why pressing the scan button did not start a scan, with the building in
## range aimed at (or null).
func miss_reason(building: Building) -> ScanMiss:
	if building != null:
		return ScanMiss.GAUGE_LOW
	if aim_far_building() != null:
		return ScanMiss.TOO_FAR
	return ScanMiss.NOTHING


## The scannable building in the middle of the view, up to
## scan_hint_distance, if no wall stands in front of it, or null.
func aim_far_building() -> Building:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * settings.scan_hint_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, Building.SCAN_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var building := hit.get("collider") as Building
	var wall_query := PhysicsRayQueryParameters3D.create(
		from, hit.position, collision_mask, [get_rid()]
	)
	wall_query.hit_from_inside = true  # A camera inside a wall sees nothing.
	var wall := space.intersect_ray(wall_query)
	# A wall in front hides the building, unless it is one of its own walls.
	if not wall.is_empty() and building.distance_to(wall.position) > FAR_AIM_WALL_MARGIN:
		return null
	return building


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


## Head pitch in radians, for the commands sent over the network.
func get_pitch() -> float:
	return _pitch


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
