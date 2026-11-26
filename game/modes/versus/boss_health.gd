class_name BossHealth
extends RefCounted
## The Versus boss's health, phases, poise and rage (spec S-024, Q7 to Q11,
## T-371). Pure: the boss node calls take_hit(), landed_hit() and update();
## the HUD and the network read the state. The played boss and the AI boss
## hold one each; online, the room's is the truth.

signal phase_changed(index: int)
signal knelt
signal died

var settings: VersusSettings
var max_health := 0.0
var health := 0.0
## Index in settings.phases of the current phase.
var phase := 0
## Rage, 0 to 100 (Q10).
var rage := 0.0
## Poise, 0 to settings.poise_max (Q11).
var poise := 0.0
## Seconds still on its knees.
var kneel_left := 0.0
## Seconds still in its Fury.
var fury_left := 0.0
var _shield_left := 0.0
var _kneel_immunity_left := 0.0
var _since_attack := 0.0


func _init(versus: VersusSettings, hunted_count: int) -> void:
	settings = versus
	max_health = versus.boss_health_per_hunted * maxi(hunted_count, 1)
	health = max_health


## Health left, 0 to 1.
func ratio() -> float:
	return health / max_health if max_health > 0.0 else 0.0


func is_dead() -> bool:
	return health <= 0.0


func is_kneeling() -> bool:
	return kneel_left > 0.0


func is_shielded() -> bool:
	return _shield_left > 0.0


func in_fury() -> bool:
	return fury_left > 0.0


## The current phase, or null without phases.
func current_phase() -> VersusPhase:
	if settings.phases.is_empty():
		return null
	return settings.phases[phase]


## Takes a hit of damage and poise; returns the damage really taken.
func take_hit(damage: float, poise_added := 0.0) -> float:
	if is_dead() or is_shielded():
		return 0.0
	var scale := 1.0
	var current := current_phase()
	if current != null:
		scale *= current.damage_taken_scale
	if is_kneeling():
		scale *= settings.kneel_damage_scale
	var taken := minf(damage * scale, health)
	health -= taken
	rage = minf(rage + taken * settings.rage_per_damage, 100.0)
	if not is_kneeling() and _kneel_immunity_left <= 0.0:
		poise += poise_added
		if poise >= settings.poise_max:
			poise = 0.0
			kneel_left = settings.kneel_time
			knelt.emit()
	_update_phase()
	if is_dead():
		died.emit()
	return taken


## The boss attacked (Q4, Q10): its rage stops draining; hit adds rage.
func attacked(hit: bool) -> void:
	_since_attack = 0.0
	if hit:
		rage = minf(rage + settings.rage_per_hit, 100.0)


## Seconds since its last attack (Q4).
func since_attack() -> float:
	return _since_attack


## Starts the Fury if the rage is full (Q9); true if it started.
func start_fury() -> bool:
	if rage < 100.0 or in_fury() or is_dead():
		return false
	rage = 0.0
	fury_left = settings.fury_time
	return true


## Speed multiplier from the phase and the Fury.
func speed_scale() -> float:
	var scale := 1.0
	var current := current_phase()
	if current != null:
		scale *= current.speed_scale
	if in_fury():
		scale *= settings.fury_speed_scale
	return scale


func update(delta: float) -> void:
	_since_attack += delta
	_shield_left = maxf(_shield_left - delta, 0.0)
	fury_left = maxf(fury_left - delta, 0.0)
	if kneel_left > 0.0:
		kneel_left = maxf(kneel_left - delta, 0.0)
		if kneel_left <= 0.0:
			_kneel_immunity_left = settings.kneel_immunity
	else:
		_kneel_immunity_left = maxf(_kneel_immunity_left - delta, 0.0)
		poise = maxf(poise - settings.poise_decay * delta, 0.0)
	if _since_attack > settings.rage_decay_delay and not in_fury():
		rage = maxf(rage - settings.rage_decay * delta, 0.0)


func _update_phase() -> void:
	var r := ratio()
	while phase + 1 < settings.phases.size() and r <= settings.phases[phase + 1].start_ratio:
		phase += 1
		if not is_dead():
			_shield_left = settings.phase_shield_time
		phase_changed.emit(phase)
