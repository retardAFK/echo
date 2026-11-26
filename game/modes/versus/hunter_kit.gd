class_name HunterKit
extends Node
## A hunted's Versus kit (spec S-024, Q5, Q13 to Q15, T-372): its health
## (HuntedVitals), stamina, flare launcher and dodge roll, plus, for the
## player, the first-person arms. A child of a Player or a Prey, added by
## VersusMode. The player's keys: left click fires, R reloads, Space rolls.
## An AI prey fires by itself at the boss when it sees it.

signal hurt(damage: int)

var mode: VersusMode
var body: CharacterBody3D
var vitals: HuntedVitals
var stamina: Stamina
var clip := 0
## True while reloading.
var reloading := false
var view_model: ViewModel
var _cooldown := 0.0
var _reload_left := 0.0
var _dodge_left := 0.0
var _dodge_velocity := Vector3.ZERO
var _ai_wait := 0.0
var _down_label: Label3D


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "HunterKit"


func _ready() -> void:
	body = get_parent()
	vitals = HuntedVitals.new(mode.settings)
	stamina = Stamina.new(mode.settings)
	clip = mode.settings.flare_clip
	vitals.downed.connect(_on_downed)
	vitals.revived.connect(_on_revived)
	if is_local():
		var camera := body.get_viewport().get_camera_3d()
		view_model = ViewModel.new(ViewModel.Kind.HUNTER)
		camera.add_child(view_model)
		if "breath_hold" in body:
			var no_breath := PlayerSettings.new()
			no_breath.breath_hold_time = 0.0  # R reloads in Versus.
			body.breath_hold = BreathHold.new(no_breath)


## Whether this machine's player drives it (else an AI prey).
func is_local() -> bool:
	return body is Player and (body as Player).local_controls


## Its eyes, where its flares leave from.
func eye() -> Vector3:
	return body.call(&"get_eye_position")


## Where it aims: the camera for the player, the boss for an AI.
func aim() -> Vector3:
	if is_local():
		return -body.get_viewport().get_camera_3d().global_basis.z
	var boss := mode.boss
	if boss == null:
		return -body.global_basis.z
	var target := boss.body.global_position + Vector3.UP * 1.2
	var distance := eye().distance_to(target)
	var flight := distance / mode.settings.flare_speed
	target.y += 0.5 * mode.settings.flare_gravity * flight * flight  # Its drop.
	return (target - eye()).normalized()


## Fires a flare if it can; true if one left.
func fire() -> bool:
	if not vitals.is_standing() or reloading or _cooldown > 0.0 or _dodge_left > 0.0:
		return false
	if clip <= 0:
		reload()
		return false
	clip -= 1
	_cooldown = mode.settings.flare_cooldown
	var direction := aim()
	var flare := Flare.new()
	flare.mode = mode
	flare.shooter = body
	flare.velocity = direction * mode.settings.flare_speed
	mode.add_flare(flare, eye() + direction * 0.5)
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, eye(), mode.settings.shot_noise_range, body)
	if view_model != null:
		view_model.kick()
	if clip == 0:
		reload()
	return true


func reload() -> void:
	if reloading or clip >= mode.settings.flare_clip or not vitals.is_standing():
		return
	reloading = true
	_reload_left = mode.settings.reload_time


## Rolls toward direction (flat) if it has the stamina (Q15).
func dodge(direction: Vector3) -> bool:
	if not vitals.is_standing() or _dodge_left > 0.0:
		return false
	direction.y = 0.0
	if direction.length() < 0.01:
		direction = body.global_basis.z  # Backwards when standing still.
	if not stamina.spend(mode.settings.dodge_cost):
		return false
	_dodge_left = mode.settings.dodge_time
	_dodge_velocity = (
		direction.normalized() * mode.settings.dodge_distance / mode.settings.dodge_time
	)
	vitals.shield(mode.settings.dodge_shield_time)
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP, body.global_position, mode.settings.dodge_noise_range, body
	)
	return true


## A blow of the boss (Q9); true if it hurt.
func take_blow(damage: int) -> bool:
	if not vitals.hurt(damage):
		return false
	hurt.emit(damage)
	if view_model != null:
		view_model.flash(Color.RED)
	return true


func _physics_process(delta: float) -> void:
	vitals.update(delta)
	stamina.update(delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			clip = mode.settings.flare_clip
	if view_model != null:
		view_model.speed = Vector2(body.velocity.x, body.velocity.z).length()
		view_model.lower(1.0 if not vitals.is_standing() else (0.4 if reloading else 0.0))
		view_model.visible = not vitals.is_out()
	if _dodge_left > 0.0:
		_dodge_left -= delta
		body.move_and_collide(_dodge_velocity * delta)
	if not vitals.is_standing() or mode.is_over():
		return
	if is_local():
		_read_keys()
	else:
		_think(delta)


func _read_keys() -> void:
	if Input.is_action_just_pressed("throw"):
		fire()
	if Input.is_action_just_pressed("hold_breath"):
		reload()
	if Input.is_action_just_pressed("dodge"):
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dodge(body.global_basis * Vector3(input.x, 0.0, input.y))


## An AI prey fires at the boss it sees within range.
func _think(delta: float) -> void:
	_ai_wait -= delta
	var boss := mode.boss
	if _ai_wait > 0.0 or boss == null or boss.health.is_dead():
		return
	_ai_wait = mode.settings.ai_fire_interval
	var target := boss.body.global_position + Vector3.UP * 1.2
	if eye().distance_to(target) > mode.settings.ai_fire_range:
		return
	var query := PhysicsRayQueryParameters3D.create(eye(), target, 1 | 2)
	if body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		fire()


func _on_downed() -> void:
	if body is Player:
		(body as Player).held = true  # It stays down where it fell.
	else:
		body.set_physics_process(false)
		_down_label = Label3D.new()
		_down_label.text = Text.t("VERSUS_DOWN")
		_down_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_down_label.position = Vector3.UP * 2.2
		body.add_child(_down_label)


func _on_revived() -> void:
	if body is Player:
		(body as Player).held = false
	else:
		body.set_physics_process(true)
		if _down_label != null:
			_down_label.queue_free()
