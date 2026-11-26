class_name BossKit
extends Node
## The Versus boss's kit (spec S-024, Q7 to Q12, T-373): its health, phases,
## poise and rage (BossHealth), its claw and its charge, each with a signal
## before the blow, and, for the played boss, its first-person arms. A child
## of a Monster (AI) or a MonsterAvatar (played), added by VersusMode.
## Played: left click claws, Space charges, R starts the Fury.
## AI: claws a hunted in reach, charges one 6 to 14 m away in sight.

signal hit_taken(face: bool)

enum Move { NONE, CLAW_WINDUP, CHARGE_WINDUP, CHARGING, STUNNED }

## Seconds the body is held still each frame while a move or a kneel lasts.
const HOLD := 0.1

var mode: VersusMode
var body: CharacterBody3D
var health: BossHealth
var move := Move.NONE
var view_model: ViewModel
var _move_left := 0.0
var _claw_wait := 0.0
var _charge_wait := 0.0
var _charge_direction := Vector3.ZERO
var _charged := 0.0
var _charge_hits: Array[HunterKit] = []
var _base_walk := 0.0
var _base_run := 0.0
var _fall := FallWatch.new()


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "BossKit"


func _ready() -> void:
	body = get_parent()
	health = BossHealth.new(mode.settings, maxi(mode.hunters.size(), 1))
	var settings: MonsterSettings = body.get(&"settings")
	_base_walk = settings.walk_speed
	_base_run = settings.run_speed
	if is_local():
		view_model = ViewModel.new(ViewModel.Kind.BOSS)
		(body as MonsterAvatar).get_camera().add_child(view_model)


## Whether this machine's player drives it (else the AI).
func is_local() -> bool:
	return body is MonsterAvatar and (body as MonsterAvatar).local_controls


## A flare hit it at point (Q13): face or body, damage and poise.
func take_flare(flare: Flare, point: Vector3) -> void:
	var eyes: Vector3 = body.call(&"get_eye_position")
	var face := point.distance_to(eyes) <= mode.settings.face_radius
	var damage := mode.settings.flare_face_damage if face else mode.settings.flare_damage
	var poise := mode.settings.flare_face_poise if face else mode.settings.flare_poise
	var taken := health.take_hit(damage, poise)
	if taken <= 0.0:
		return
	if face and move == Move.CLAW_WINDUP:
		_end_move()  # A flare in the face breaks its blow.
	hit_taken.emit(face)
	mode.on_boss_hit(self, flare.shooter, face, taken)
	if view_model != null:
		view_model.flash(Color.WHITE)


## Starts the claw (Q9) if it can.
func claw() -> bool:
	if move != Move.NONE or _claw_wait > 0.0:
		return false
	move = Move.CLAW_WINDUP
	_move_left = mode.settings.claw_windup
	_hold()  # From now: its own AI must not turn it away this frame.
	_play_gesture(MonsterBody.Action.CATCH, mode.settings.claw_windup + 0.3)
	if view_model != null:
		view_model.lower(-0.3)
	return true


## Starts the charge toward direction (Q9) if it can.
func charge(direction: Vector3) -> bool:
	if move != Move.NONE or _charge_wait > 0.0:
		return false
	direction.y = 0.0
	if direction.length() < 0.01:
		return false
	_charge_direction = direction.normalized()
	move = Move.CHARGE_WINDUP
	_move_left = mode.settings.charge_windup
	_hold()
	MonsterNoise.scream(body)  # The roar: the signal (Q9).
	if view_model != null:
		view_model.lower(0.5)
	return true


## Lands after a fall of height meters (Q34): a noise, and from high up a
## share of its health and a short stun.
func land(height: float) -> void:
	var settings := mode.settings
	if FallRules.is_loud(settings, height):
		NoiseBus.emit_noise(
			NoiseEvent.Type.FOOTSTEP, body.global_position, settings.fall_noise_range, body
		)
	var damage := FallRules.boss_damage(settings, height, health.max_health)
	if damage <= 0.0:
		return
	health.take_hit(damage, 0.0)
	if move == Move.NONE:
		move = Move.STUNNED
		_move_left = settings.boss_fall_stun


## Forgets the fall under way: it was moved to its start (Q29).
func reset_fall() -> void:
	_fall.reset()


func _physics_process(delta: float) -> void:
	health.update(delta)
	var fallen := _fall.update(body.is_on_floor(), body.global_position.y)
	if fallen > 0.0:
		land(fallen)
	_claw_wait = maxf(_claw_wait - delta, 0.0)
	_charge_wait = maxf(_charge_wait - delta, 0.0)
	var settings: MonsterSettings = body.get(&"settings")
	settings.walk_speed = _base_walk * health.speed_scale()
	settings.run_speed = _base_run * health.speed_scale()
	if health.is_dead() or mode.is_over():
		_hold()
		return
	if health.is_kneeling():
		_hold()
		return
	match move:
		Move.CLAW_WINDUP:
			_hold()
			_move_left -= delta
			if _move_left <= 0.0:
				_land_claw()
		Move.CHARGE_WINDUP:
			_hold()
			_move_left -= delta
			if _move_left <= 0.0:
				move = Move.CHARGING
				_charged = 0.0
				_charge_hits.clear()
		Move.CHARGING:
			_hold()
			_charge_step(delta)
		Move.STUNNED:
			_hold()
			_move_left -= delta
			if _move_left <= 0.0:
				_end_move()
		Move.NONE:
			if is_local():
				_read_keys()
			else:
				_think()


func _read_keys() -> void:
	if Input.is_action_just_pressed("throw"):
		claw()
	if Input.is_action_just_pressed("dodge"):
		charge(-body.global_basis.z)
	if Input.is_action_just_pressed("hold_breath"):
		health.start_fury()


## The AI boss's choice (Q12, prototype): claw in reach, charge from afar.
func _think() -> void:
	health.start_fury()
	var target := mode.nearest_standing(body.global_position)
	if target == null:
		return
	var offset := target.body.global_position - body.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= mode.settings.claw_reach * 0.9:
		_face(offset)
		claw()
	elif (
		distance >= mode.settings.charge_min_distance
		and distance <= mode.settings.charge_distance
		and _sees(target)
	):
		_face(offset)
		charge(offset)


func _land_claw() -> void:
	var hit := false
	for hunter in mode.hunters:
		if (
			hunter.vitals.is_standing()
			and ShotMath.in_arc(
				body.global_position,
				-body.global_basis.z,
				hunter.body.global_position,
				mode.settings.claw_reach,
				mode.settings.claw_half_angle,
				mode.settings.claw_height
			)
			and hunter.take_blow(mode.settings.claw_damage)
		):
			hit = true
	health.attacked(hit)
	if view_model != null:
		view_model.swipe()
	_claw_wait = mode.settings.claw_cooldown
	_end_move()


func _charge_step(delta: float) -> void:
	var step := mode.settings.charge_speed * delta
	var collision := body.move_and_collide(_charge_direction * step)
	_charged += step
	for hunter in mode.hunters:
		if hunter in _charge_hits or not hunter.vitals.is_standing():
			continue
		var gap := hunter.body.global_position - body.global_position
		gap.y = 0.0
		if gap.length() <= mode.settings.charge_hit_radius:
			_charge_hits.append(hunter)
			hunter.take_blow(mode.settings.charge_damage)
	if collision != null and not collision.get_collider() is CharacterBody3D:
		if collision.get_normal().dot(_charge_direction) < -0.5:
			health.attacked(not _charge_hits.is_empty())
			_charge_wait = mode.settings.charge_cooldown
			move = Move.STUNNED  # Into a wall: stunned (Q9).
			_move_left = mode.settings.charge_stun
			return
	if _charged >= mode.settings.charge_distance:
		health.attacked(not _charge_hits.is_empty())
		_charge_wait = mode.settings.charge_cooldown
		_end_move()


func _end_move() -> void:
	move = Move.NONE
	if view_model != null:
		view_model.lower(0.0)


## Keeps its own movement off while a move, a stun or a kneel lasts.
func _hold() -> void:
	if body is Monster:
		(body as Monster).hold_still(HOLD)
	elif "stagger" in body:
		(body.stagger as Stagger).hit(HOLD)


func _face(offset: Vector3) -> void:
	if offset.length() > 0.01:
		body.look_at(body.global_position + offset, Vector3.UP)


func _sees(target: HunterKit) -> bool:
	var eyes: Vector3 = body.call(&"get_eye_position")
	var query := PhysicsRayQueryParameters3D.create(eyes, target.eye(), 1 | 2)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _play_gesture(action: MonsterBody.Action, seconds: float) -> void:
	if "gesture" in body:
		(body.gesture as BodyGesture).play(action, seconds)
