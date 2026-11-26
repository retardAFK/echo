class_name BossKit
extends Node
## The Versus boss's kit (spec S-024, Q7 to Q12, T-373): its health, phases,
## poise and rage (BossHealth), its claw and its charge, each with a signal
## before the blow, and, for the played boss, its first-person arms. A child
## of a Monster (AI) or a MonsterAvatar (played), added by VersusMode.
## Played: left click claws, Space charges, R starts the Fury, interact
## held by a downed hunted finishes it (Q5, DownedHold), else interact
## leaps onto the noise aimed at (phase 2+, BossLeap). Each new phase starts
## with a cry; in phase 3 the claw strikes twice (Q8).
## AI (T-382): BossBrain chooses (target, claw, charge, leap onto a lone
## shooter, backing off before a kneel), the kit does it; it starts the Fury
## as soon as it can and finishes a downed hunted at its feet when no
## standing one is in reach.
## Any blow that makes it flinch breaks a finish.

signal hit_taken(face: bool)

enum Move { NONE, CLAW_WINDUP, CHARGE_WINDUP, CHARGING, STUNNED, LEAPING }

## Seconds the body is held still each frame while a move or a kneel lasts.
const HOLD := 0.1

var mode: VersusMode
var body: CharacterBody3D
var health: BossHealth
var move := Move.NONE
## The keys of its player, held and pressed (T-381).
var keys := HeldKeys.new()
## Holding interact by a downed hunted to finish it (Q5).
var finish := DownedHold.new()
## Its leap (phase 2+), and the noises it may leap onto.
var leap: BossLeap
## The AI's choices (T-382); unused when a human plays it.
var brain: BossBrain
## A client's copy of its prompt (T-381), as the room says.
var mirror_prompt: Array = []
var view_model: ViewModel
## Its look (S-025): bigger, glowing, with the hitbox the shots meet.
var look: BossLook
var _move_left := 0.0
var _claw_wait := 0.0
var _charge_wait := 0.0
var _charge_direction := Vector3.ZERO
var _charged := 0.0
var _charge_hits: Array[HunterKit] = []
var _base_walk := 0.0
var _base_run := 0.0
var _fall := FallWatch.new()
var _slow_left := 0.0
var _push_velocity := Vector3.ZERO
var _push_left := 0.0
var _second_claw := false


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "BossKit"


func _ready() -> void:
	body = get_parent()
	health = BossHealth.new(mode.settings, maxi(mode.hunters.size(), 1))
	var settings: MonsterSettings = body.get(&"settings")
	_base_walk = settings.walk_speed
	_base_run = settings.run_speed
	hit_taken.connect(func(_face: bool) -> void: finish.reset())
	leap = BossLeap.new(mode.settings)
	brain = BossBrain.new(mode.settings)
	health.phase_changed.connect(_on_phase_changed)
	NoiseBus.noise_emitted.connect(_on_noise)
	if is_local():
		view_model = ViewModel.new(ViewModel.Kind.BOSS)
		(body as MonsterAvatar).get_camera().add_child(view_model)


## Whether this machine's player drives it (its arms and HUD show here).
func is_local() -> bool:
	return body is MonsterAvatar and (body as MonsterAvatar).local_controls


## Whether a human plays it through its commands: here, or on the room
## (T-381). Else the AI (or a client's mirror of its own avatar).
func is_played() -> bool:
	return body is MonsterAvatar and not (body as MonsterAvatar).mirror_world


## A flare hit it at point (Q13): face or body, damage and poise.
func take_flare(flare: Flare, point: Vector3) -> void:
	var face := is_face(point)
	var settings := mode.settings
	var damage := settings.flare_face_damage if face else settings.flare_damage
	var poise := settings.flare_face_poise if face else settings.flare_poise
	_take(flare.shooter, point, damage, poise, face)


## A pellet of shooter's gun hit it at point (S-025, T-403): face or body,
## its damage times power (the gun's rarity, T-404).
func take_shot(shooter: Node3D, point: Vector3, gun: VersusWeapon, power := 1.0) -> void:
	var face := is_face(point)
	var hit := HitscanShot.hit_of(gun, face, power)
	_take(shooter, point, hit[0], hit[1], face)


## A flash grenade went off near it (S-025, T-404): stunned for seconds,
## its blow broken.
func stun(seconds: float) -> void:
	if health.is_dead() or move == Move.LEAPING:
		return
	_end_move()
	move = Move.STUNNED
	_move_left = seconds
	hit_taken.emit(false)
	if view_model != null:
		view_model.flash(Color.WHITE)
	if is_local() and mode.hud != null:
		mode.hud.show_blind(seconds)


## Whether point is on its face (Q13): near its eyes.
func is_face(point: Vector3) -> bool:
	return point.distance_to(eyes()) <= mode.settings.face_radius * mode.settings.boss_scale


## Where its eyes are on its model, made bigger (S-025, BossLook).
func eyes() -> Vector3:
	var own: Vector3 = body.call(&"get_eye_position")
	var feet := body.global_position
	return feet + (own - feet) * mode.settings.boss_scale


func _take(shooter: Node3D, point: Vector3, damage: float, poise: float, face: bool) -> void:
	var taken := health.take_hit(damage, poise)
	if taken <= 0.0:
		return
	if face and move == Move.CLAW_WINDUP:
		_end_move()  # A shot in the face breaks its blow.
	hit_taken.emit(face)
	mode.on_boss_hit(self, shooter, face, taken, point)
	if view_model != null:
		view_model.flash(Color.WHITE)


## The UV laser of shooter burns it at point for delta seconds (Q13): face
## or body, and it is slowed while the beam stays on it.
func take_laser(shooter: Node3D, point: Vector3, delta: float) -> void:
	var settings := mode.settings
	var face := is_face(point)
	var damage := settings.laser_damage_per_second * delta * (2.0 if face else 1.0)
	_slow_left = maxf(_slow_left, delta * 2.0 + 0.1)
	var taken := health.take_hit(damage, 0.0)
	if taken > 0.0:
		mode.on_boss_hit(self, shooter, face, taken, point, true)


## The sonic shotgun's blast from offset's direction (S-025): pushed back
## distance, its blow broken, poise added.
func blasted(offset: Vector3, distance: float, poise: float) -> void:
	var settings := mode.settings
	offset.y = 0.0
	if offset.length() > 0.01:
		_push_velocity = offset.normalized() * distance / settings.sonic_push_time
		_push_left = settings.sonic_push_time
	if move in [Move.CLAW_WINDUP, Move.CHARGE_WINDUP, Move.CHARGING]:
		_end_move()
	health.take_hit(0.0, poise)
	hit_taken.emit(false)


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


## What holding interact does now (KitPrompts), or on a client what the room
## says.
func shown_prompt() -> Array:
	return mirror_prompt if mode.mirror else KitPrompts.of_boss(self)


## Whether its phase lets it leap now (Q9).
func can_leap() -> bool:
	var phase := health.current_phase()
	return phase != null and phase.can_leap and leap.wait <= 0.0


## Starts the leap onto target (Q9) if it can.
func leap_to(target: Vector3) -> bool:
	if move != Move.NONE or not can_leap():
		return false
	_face(target - body.global_position)
	leap.start(body.global_position, target)
	move = Move.LEAPING
	_hold()
	mode.show_leap(target)
	_play_gesture(MonsterBody.Action.CATCH, mode.settings.leap_time)
	return true


func _physics_process(delta: float) -> void:
	if view_model != null:
		view_model.visible = mode.first_person()  # Behind the shoulder: no arms (S-025).
	if mode.mirror:
		return  # A client (T-381): the room plays, the HUD shows its copy.
	if is_played():
		keys.update((body as MonsterAvatar).commands)
	health.update(delta)
	leap.update(delta)
	var fallen := _fall.update(body.is_on_floor(), body.global_position.y)
	if fallen > 0.0:
		land(fallen)
	_claw_wait = maxf(_claw_wait - delta, 0.0)
	_charge_wait = maxf(_charge_wait - delta, 0.0)
	var settings: MonsterSettings = body.get(&"settings")
	_slow_left = maxf(_slow_left - delta, 0.0)
	var slow := 1.0 - mode.settings.laser_slow if _slow_left > 0.0 else 1.0
	settings.walk_speed = _base_walk * health.speed_scale() * slow
	settings.run_speed = _base_run * health.speed_scale() * slow
	if _push_left > 0.0:
		_push_left -= delta
		body.move_and_collide(_push_velocity * delta)
		_hold()
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
		Move.LEAPING:
			_hold()
			body.global_position = leap.fly(delta)
			if not leap.leaping:
				_land_leap()
		Move.STUNNED:
			_hold()
			_move_left -= delta
			if _move_left <= 0.0:
				_end_move()
		Move.NONE:
			if is_played():
				_read_commands((body as MonsterAvatar).commands, delta)
			elif not body is MonsterAvatar:
				_think(delta)
	if move != Move.NONE:
		finish.reset()


## One frame of interact held (pressed) or not by a downed hunted (Q5): it
## stands still over it, and once held long enough it is out.
func hold_finish(pressed: bool, delta: float) -> void:
	var settings := mode.settings
	var done := finish.update(
		mode.hunters,
		body.global_position,
		pressed,
		delta,
		settings.finish_time,
		settings.finish_reach
	)
	if finish.target != null:
		_hold()
	if done != null:
		done.vitals.finish()


## The player's keys (T-381), from its commands: the same on this machine
## and on the room. Left click claws, Space charges, R starts the Fury,
## interact finishes or leaps.
func _read_commands(commands: PlayerCommands, delta: float) -> void:
	hold_finish(keys.held(PlayerCommands.FLAG_INTERACT), delta)
	if finish.target != null:
		return
	if keys.pressed(PlayerCommands.FLAG_INTERACT) and can_leap():
		var eyes: Vector3 = body.call(&"get_eye_position")
		var aim := -Basis.from_euler(Vector3(commands.pitch, commands.yaw, 0.0)).z
		var target: Variant = leap.pick(eyes, aim)
		if target != null:
			leap_to(target)
			return
	if keys.pressed(PlayerCommands.FLAG_FIRE):
		claw()
	if keys.pressed(PlayerCommands.FLAG_DODGE):
		charge(-body.global_basis.z)
	if keys.pressed(PlayerCommands.FLAG_BREATH):
		health.start_fury()


## The AI boss's turn (Q12, T-382): BossBrain chooses, the kit does it.
func _think(delta: float) -> void:
	health.start_fury()
	brain.update(delta)
	var standing: Array[HunterKit] = []
	var places: Array[Vector3] = []
	var damage: Array[float] = []
	for kit in mode.hunters:
		if kit.vitals.is_standing():
			standing.append(kit)
			places.append(kit.body.global_position)
			damage.append(mode.stats.damage_of(kit) if mode.stats != null else 0.0)
	var index := brain.pick_target(body.global_position, places, damage)
	var target: HunterKit = standing[index] if index >= 0 else null
	var offset := Vector3.ZERO
	if target != null:
		offset = target.body.global_position - body.global_position
		offset.y = 0.0
	var distance := offset.length() if target != null else INF
	hold_finish(distance > mode.settings.claw_reach, delta)
	if finish.target != null or target == null:
		return
	var lone: Variant = _lone_noise(places)
	var sees := distance <= mode.settings.charge_distance and _sees(target)
	match brain.choose(distance, sees, lone != null, health.poise / mode.settings.poise_max):
		BossBrain.Act.CLAW:
			_face(offset)
			claw()
		BossBrain.Act.CHARGE:
			_face(offset)
			charge(offset)
		BossBrain.Act.LEAP:
			leap_to(lone)
		BossBrain.Act.RETREAT:
			if body is Monster:
				(body as Monster).walk_away(target.body.global_position)


## A heard noise next to a lone shooter (phase 2+), its leap target, or null.
func _lone_noise(places: Array[Vector3]) -> Variant:
	if not can_leap():
		return null
	for i in places.size():
		if not brain.is_lone(i, places):
			continue
		var noise: Variant = leap.pick(body.global_position, Vector3.ZERO, places[i])
		if (
			noise != null
			and (noise as Vector3).distance_to(places[i]) < mode.settings.brain_leap_near
		):
			return noise
	return null


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
	var phase := health.current_phase()
	if phase != null and phase.double_claw and not _second_claw:
		_second_claw = true  # Enraged: a second blow right after (Q8).
		_move_left = mode.settings.double_claw_delay
		return
	_second_claw = false
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


## The landing (Q9): a shock wave hurts and throws the standing hunted near.
func _land_leap() -> void:
	var hit := false
	var settings := mode.settings
	for hunter in mode.hunters:
		var offset := hunter.body.global_position - body.global_position
		offset.y = 0.0
		if not hunter.vitals.is_standing() or offset.length() > settings.leap_radius:
			continue
		if hunter.take_blow(settings.leap_damage):
			hit = true
			hunter.knock(offset.normalized() * settings.leap_knock)
	health.attacked(hit)
	NoiseBus.emit_noise(NoiseEvent.Type.IMPACT, body.global_position, settings.leap_range, body)
	_end_move()


## A new phase (Q8): its cry, heard far.
func _on_phase_changed(index: int) -> void:
	if index > 0:
		MonsterNoise.scream(body)


## It remembers where the hunted made noise (its leap targets).
func _on_noise(event: NoiseEvent) -> void:
	if event.source == body:
		return
	for hunter in mode.hunters:
		if event.source == hunter.body:
			leap.hear(event.position)
			return


func _exit_tree() -> void:
	if NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.disconnect(_on_noise)


func _end_move() -> void:
	move = Move.NONE
	_second_claw = false
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
