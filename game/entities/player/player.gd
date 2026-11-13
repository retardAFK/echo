class_name Player
extends CharacterBody3D
## First-person player controller (spec S-001).
## Movement math lives in PlayerMotion, tunable values in PlayerSettings.

## Emitted when the player switches between crouching, walking and sprinting.
## The noise system (S-002) listens to it.
signal gait_changed(gait: PlayerMotion.Gait)
## The player used a ruse (S-008): "bottle", "decoy", "hide" or "car_alarm".
signal ruse_used(kind: StringName)

## Something in reach is used only if it lies within this angle of the
## crosshair, seen from above (radians).
const AIM_ANGLE := deg_to_rad(35.0)
const BOTTLE_SCENE := preload("res://game/entities/bottle/thrown_bottle.tscn")
const DECOY_SCENE := preload("res://game/entities/decoy/decoy.tscn")
## How far down an alarm clock looks for the ground in front of the player, in meters.
const DECOY_GROUND_SEARCH := 2.5

@export var settings: PlayerSettings
## Values of the ruses: bottles, alarm clocks, hiding spots (S-008).
@export var ruse_settings: RuseSettings

## What the player carries (S-008).
var inventory: Inventory
## The hiding spot the player is in (S-008, Q6), or null.
var hiding_in: HidingSpot
## What the player asks this frame (S-010, T-106): from the keyboard and
## mouse when local_controls is on, else set by the network.
var commands := PlayerCommands.new()
## Whether this machine's keyboard and mouse drive the player.
var local_controls := true

var _gait := PlayerMotion.Gait.WALK
var _wants_crouch := false
var _pitch := 0.0
var _height := 0.0
var _bob_phase := 0.0
var _capsule: CapsuleShape3D
var _headroom_sphere: SphereShape3D
var _hold := HoldInteraction.new()
var _hide_yaw := 0.0
var _breathless_left := 0.0
var _breath_timer := 0.0
var _controls: LocalControls

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _headroom_cast: ShapeCast3D = $HeadroomCast


func _ready() -> void:
	inventory = Inventory.new(ruse_settings)
	# Each player owns its capsule, so resizing it never touches another instance.
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_capsule.radius = settings.capsule_radius
	_headroom_sphere = SphereShape3D.new()
	_headroom_sphere.radius = settings.capsule_radius
	_headroom_cast.shape = _headroom_sphere
	_apply_height(settings.standing_height)
	if local_controls:
		_controls = LocalControls.new()
		_controls.commands = commands
		add_child(_controls)


func _physics_process(delta: float) -> void:
	if _controls != null:
		_controls.fill()
	apply_actions()
	_update_breath(delta)
	if hiding_in != null:
		# Hidden (S-008, Q6): no movement, only holding "interact" to get out.
		_update_height(delta)
		_hold.update(self, hiding_in, commands.interact, delta)
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := commands.move
	_set_gait(
		PlayerMotion.resolve_gait(
			_wants_crouch,
			commands.sprint,
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
	_hold.update(self, get_interactable(), commands.interact, delta)


## Applies the one-shot actions queued in the commands (S-010, T-106).
func apply_actions() -> void:
	for action in commands.take_actions():
		match action:
			PlayerCommands.Action.CROUCH:
				toggle_crouch()
			PlayerCommands.Action.INTERACT:
				interact()
			PlayerCommands.Action.THROW:
				throw_bottle()
			PlayerCommands.Action.DECOY:
				place_decoy()


## Turns the body (yaw) and the head (pitch) from a mouse movement in screen pixels.
func look(relative: Vector2) -> void:
	var sensitivity := deg_to_rad(settings.mouse_sensitivity)
	rotate_y(-relative.x * sensitivity)
	_pitch = PlayerMotion.clamp_pitch(_pitch - relative.y * sensitivity, settings)
	if hiding_in != null:
		# Through the slit, the head turns only a little (S-008, Q6).
		var yaw_limit := deg_to_rad(ruse_settings.hidden_yaw_limit)
		var turned := clampf(angle_difference(_hide_yaw, rotation.y), -yaw_limit, yaw_limit)
		rotation.y = _hide_yaw + turned
		var pitch_limit := deg_to_rad(ruse_settings.hidden_pitch_limit)
		_pitch = clampf(_pitch, -pitch_limit, pitch_limit)
	_head.rotation.x = _pitch


## The nearest thing in reach, in front of the crosshair, that the player can
## use (a car alarm, S-006), or null. A pickup it has no room for is skipped.
func get_interactable() -> Node:
	if hiding_in != null:
		return hiding_in  # Hidden: the only thing in reach is the way out.
	var best: Node = null
	var best_distance := INF
	var forward := -_camera.global_basis.z
	var aim := Vector2(forward.x, forward.z).normalized()
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if not node.can_interact(global_position):
			continue
		if node.has_method("wanted_by") and not node.wanted_by(self):
			continue
		var gap: Vector3 = node.global_position - global_position
		var flat := Vector2(gap.x, gap.z)
		if flat.length() > 0.01 and aim.dot(flat.normalized()) < cos(AIM_ANGLE):
			continue  # In reach but not in front of the crosshair.
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


## Uses the nearest thing in reach in front of the crosshair, if any.
func interact() -> void:
	var target := get_interactable()
	if target == null:
		return
	if target is CarAlarm and target.can_interact(global_position):
		ruse_used.emit(&"car_alarm")
	target.interact(self)


## Throws a bottle where the camera looks, a little upward (S-008, Q2), if the
## player carries one. The gesture makes a faint noise.
func throw_bottle() -> ThrownBottle:
	if hiding_in != null or not inventory.use(Inventory.Kind.BOTTLE):
		return null
	var forward := -_camera.global_basis.z
	var right := _camera.global_basis.x
	var direction := forward.rotated(right, deg_to_rad(ruse_settings.throw_lift)).normalized()
	var bottle: ThrownBottle = BOTTLE_SCENE.instantiate()
	get_parent().add_child(bottle)
	bottle.global_position = (_camera.global_position + forward * ruse_settings.throw_hand_offset)
	bottle.linear_velocity = direction * ruse_settings.throw_speed
	NoiseBus.emit_noise(NoiseEvent.Type.THROW, global_position, ruse_settings.gesture_range, self)
	ruse_used.emit(&"bottle")
	return bottle


## Places an alarm clock on the ground in front of the player (S-008, Q3), if
## the player carries one, or at their feet when there is no ground there.
## The gesture makes a faint noise.
func place_decoy() -> Decoy:
	if hiding_in != null or not inventory.use(Inventory.Kind.DECOY):
		return null
	var offset := -global_basis.z * ruse_settings.decoy_place_distance
	var spot := global_position
	if not test_move(global_transform, offset):  # A wall in front: at the feet.
		var ahead := global_position + offset
		var query := PhysicsRayQueryParameters3D.create(
			ahead + Vector3.UP, ahead + Vector3.DOWN * DECOY_GROUND_SEARCH, collision_mask
		)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			spot = hit.position
	var decoy: Decoy = DECOY_SCENE.instantiate()
	get_parent().add_child(decoy)
	decoy.global_position = spot
	NoiseBus.emit_noise(NoiseEvent.Type.THROW, global_position, ruse_settings.gesture_range, self)
	ruse_used.emit(&"decoy")
	return decoy


## Gets into a hiding spot (S-008, Q6): the body stops and stops colliding,
## the eyes go inside the spot, looking out of its front.
func hide_in(spot: HidingSpot) -> void:
	hiding_in = spot
	velocity = Vector3.ZERO
	_collision.disabled = true
	global_position = spot.global_position
	_hide_yaw = spot.get_out_yaw()
	rotation.y = _hide_yaw
	_pitch = 0.0
	_head.rotation.x = 0.0
	_wants_crouch = spot.crouched
	_set_gait(PlayerMotion.Gait.CROUCH if spot.crouched else PlayerMotion.Gait.WALK)
	ruse_used.emit(&"hide")


## Gets out of the hiding spot, in front of it.
func leave_hiding() -> void:
	if hiding_in == null:
		return
	global_position = hiding_in.get_exit_point()
	hiding_in = null
	_collision.disabled = false
	velocity = Vector3.ZERO


func is_hidden() -> bool:
	return hiding_in != null


## Whether the player is out of breath after a sprint (D-009).
func is_breathless() -> bool:
	return _breathless_left > 0.0


## Out of breath for a while after a sprint, the player pants faintly: a
## BREATH noise so short that only the monster's scan reveals it (D-009),
## hidden or not (S-008, Q6).
func _update_breath(delta: float) -> void:
	if _gait == PlayerMotion.Gait.SPRINT and hiding_in == null:
		_breathless_left = settings.breathless_time
		_breath_timer = 0.0
		return
	if _breathless_left <= 0.0:
		return
	_breathless_left -= delta
	_breath_timer -= delta
	if _breath_timer <= 0.0:
		_breath_timer += settings.breath_interval
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, get_eye_position(), settings.breath_range, self)


## Progress of what the player holds "interact" on (a fuse box, the
## transformer, S-007), from 0 to 1.
func get_hold_ratio() -> float:
	return _hold.get_ratio()


## Switches between crouching and standing (crouch key, toggle mode).
func toggle_crouch() -> void:
	_wants_crouch = not _wants_crouch


func get_pitch() -> float:
	return _pitch


func get_gait() -> PlayerMotion.Gait:
	return _gait


func get_height() -> float:
	return _height


## World position of the eyes, what the monster tries to see (S-003).
func get_eye_position() -> Vector3:
	return _head.global_position


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
