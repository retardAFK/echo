class_name PreyBrain
extends RefCounted
## Decisions of the AI prey (spec S-004, Q4 and Q5), testable without a scene.
## It wanders between points, runs to the hiding spot farthest from the
## monster when it hears or sees it, hides crouched and silent for a while,
## and freezes when it notices the lights of a scan. After running, it stays
## out of breath for a few seconds.

signal state_changed(state: State)

enum State { WANDER, FLEE, HIDE, FREEZE }

var state := State.WANDER
## Where the prey is heading.
var target := Vector3.ZERO

var _settings: PreySettings
var _wander_points: Array[Vector3] = []
var _hiding_spots: Array[Vector3] = []
var _wander_index := 0
var _pause_left := 0.0
var _hide_left := 0.0
var _breath_left := 0.0
var _rng := RandomNumberGenerator.new()


func _init(settings: PreySettings, rng_seed := 0) -> void:
	_settings = settings
	_rng.seed = rng_seed


func set_points(wander_points: Array[Vector3], hiding_spots: Array[Vector3]) -> void:
	_wander_points = wander_points
	_hiding_spots = hiding_spots
	_pause_left = _settings.wander_pause
	if not _wander_points.is_empty():
		target = _wander_points[_wander_index]


## Gait the prey moves at: walks, runs away, crouches in hiding.
func get_gait() -> PlayerMotion.Gait:
	match state:
		State.FLEE:
			return PlayerMotion.Gait.SPRINT
		State.HIDE:
			return PlayerMotion.Gait.CROUCH
	return PlayerMotion.Gait.WALK


## True when the prey does not move at all (hiding, frozen, pausing).
func is_still(arrived: bool) -> bool:
	return state == State.HIDE or state == State.FREEZE or (state == State.WANDER and arrived)


func is_breathless() -> bool:
	return _breath_left > 0.0


## One decision step.
## alarm: it hears or sees the monster now. threat: where the monster is.
## arrived: it reached its target. warning: it noticed the lights of a scan.
func update(delta: float, alarm: bool, threat: Vector3, arrived: bool, warning: bool) -> void:
	if state == State.FLEE:
		_breath_left = _settings.breathless_time
	else:
		_breath_left = maxf(_breath_left - delta, 0.0)
	match state:
		State.WANDER:
			if alarm:
				_flee(threat)
			elif warning:
				_set_state(State.FREEZE)
			elif arrived:
				_pause_left -= delta
				if _pause_left <= 0.0:
					_next_wander_point()
		State.FREEZE:
			if alarm:
				_flee(threat)
			elif not warning:
				_set_state(State.WANDER)
		State.FLEE:
			if arrived:
				_hide_left = _settings.hide_time
				_set_state(State.HIDE)
		State.HIDE:
			if alarm:
				_hide_left = _settings.hide_time  # Still there: stay put longer.
			_hide_left -= delta
			if _hide_left <= 0.0:
				_next_wander_point()
				_set_state(State.WANDER)


## The target cannot be reached: a fleeing prey hides where it is, a
## wandering one picks another point.
func give_up() -> void:
	match state:
		State.FLEE:
			_hide_left = _settings.hide_time
			_set_state(State.HIDE)
		State.WANDER:
			_next_wander_point()


## Sends the prey to wander from scratch, at a position (after a catch).
func reset(at_index: int) -> void:
	_breath_left = 0.0
	_wander_index = at_index
	_pause_left = _settings.wander_pause
	if not _wander_points.is_empty():
		target = _wander_points[_wander_index]
	_set_state(State.WANDER)


func _flee(threat: Vector3) -> void:
	if _hiding_spots.is_empty():
		return
	target = _hiding_spots[MonsterBrain.farthest_index(_hiding_spots, threat)]
	_breath_left = _settings.breathless_time
	_set_state(State.FLEE)


func _next_wander_point() -> void:
	if _wander_points.size() < 2:
		return
	var next := _wander_index
	while next == _wander_index:
		next = _rng.randi_range(0, _wander_points.size() - 1)
	_wander_index = next
	_pause_left = _settings.wander_pause
	target = _wander_points[_wander_index]


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(new_state)
