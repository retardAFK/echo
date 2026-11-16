class_name PreyBrain
extends RefCounted
## Decisions of the AI prey (spec S-004, Q4 and Q5), testable without a scene.
## It wanders between points, runs to the hiding spot farthest from the
## monster when it hears or sees it, hides crouched and silent for a while,
## and freezes when it notices the lights of a scan. After running, it stays
## out of breath for a few seconds.
## In the game loop (S-007, Q7), it plays the hunted's loop instead of
## wandering: SEARCH walks to the fuse slots one by one, then to the
## transformer, WORK holds "interact" there, ESCAPE runs to the exit. Its
## S-004 caution comes first: fleeing, hiding or freezing stops the work, then
## it goes back to where it was going.

signal state_changed(state: State)

enum State { WANDER, FLEE, HIDE, FREEZE, SEARCH, WORK, ESCAPE }
## What the loop asks for now: fuses, the transformer, the exit, or a task
## of the other objectives (S-018, T-268) at a point.
enum Goal { FUSES, REPAIR, EXIT, TASK }

var state := State.WANDER
## Where the prey is heading.
var target := Vector3.ZERO
## Game loop (S-007): what it goes for, and the fuse slot it is heading to.
var goal := Goal.FUSES
var slot_index := 0

## It runs to its task: a relay switch against the clock (S-018, T-268).
var rush := false

var _settings: PreySettings
var _wander_points: Array[Vector3] = []
var _hiding_spots: Array[Vector3] = []
var _wander_index := 0
var _pause_left := 0.0
var _hide_left := 0.0
var _breath_left := 0.0
var _rng := RandomNumberGenerator.new()
## Game loop (S-007): the fuse slots in visiting order, where to stand to
## repair, where the exit is.
var _loop := false
var _slots: Array[Vector3] = []
var _transformer_point := Vector3.ZERO
var _exit_point := Vector3.ZERO
var _task_point := Vector3.ZERO


func _init(settings: PreySettings, rng_seed := 0) -> void:
	_settings = settings
	_rng.seed = rng_seed


## Draws its next choices from another seed.
func reseed(rng_seed: int) -> void:
	_rng.seed = rng_seed


func set_points(wander_points: Array[Vector3], hiding_spots: Array[Vector3]) -> void:
	_wander_points = wander_points
	_hiding_spots = hiding_spots
	_pause_left = _settings.wander_pause
	if not _wander_points.is_empty():
		target = _wander_points[_wander_index]


## Leaves its way for a moment to go and take something (S-008, Q9), only
## while it searches calmly.
func detour_to(point: Vector3) -> bool:
	if state != State.SEARCH:
		return false
	target = point
	return true


## Back on its way after a detour.
func end_detour() -> void:
	if state == State.SEARCH:
		_resume()


## Flees to this point instead (a hiding spot out of the monster's sight, S-008).
func flee_to(point: Vector3) -> void:
	if state == State.FLEE:
		target = point


## Where the current goal of the loop is (S-008: a bottle is thrown away from it).
func get_goal_point() -> Vector3:
	return _goal_point()


## Plays the game loop (S-007): slots in visiting order, the point beside the
## transformer, the far end of the tunnel.
func set_loop(slots: Array[Vector3], transformer_point: Vector3, exit_point: Vector3) -> void:
	_loop = true
	_slots = slots
	_transformer_point = transformer_point
	_exit_point = exit_point
	goal = Goal.FUSES
	slot_index = 0
	_resume()


func is_looping() -> bool:
	return _loop


## The slot it reached has no fuse: on to the next one (around again if needed).
func next_slot() -> void:
	if _slots.is_empty():
		return
	slot_index = (slot_index + 1) % _slots.size()
	target = _slots[slot_index]


## It reached a full box, or the transformer with fuses to place: it holds.
func start_work() -> void:
	_set_state(State.WORK)


## The work in hand is done. found: fuses found so far; needed: fuses to find;
## repaired: whether the transformer is repaired.
func work_done(found: int, needed: int, repaired: bool) -> void:
	if repaired:
		goal = Goal.EXIT
	elif found >= needed:
		goal = Goal.REPAIR
	elif goal == Goal.FUSES:
		next_slot()
	else:
		goal = Goal.FUSES  # A teammate's fuses went back into the boxes (T-100).
	_resume()


## Gait the prey moves at: walks, runs away, crouches in hiding.
func get_gait() -> PlayerMotion.Gait:
	match state:
		State.FLEE, State.ESCAPE:
			return PlayerMotion.Gait.SPRINT
		State.HIDE:
			return PlayerMotion.Gait.CROUCH
		State.SEARCH:
			if goal == Goal.TASK and rush:
				return PlayerMotion.Gait.SPRINT
	return PlayerMotion.Gait.WALK


## True when the prey does not move at all (hiding, frozen, pausing).
func is_still(arrived: bool) -> bool:
	return state in [State.HIDE, State.FREEZE, State.WORK] or (state == State.WANDER and arrived)


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
		State.SEARCH, State.WORK, State.ESCAPE:
			if alarm:
				_flee(threat)
			elif warning and state != State.ESCAPE:
				_set_state(State.FREEZE)
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
				_resume()
		State.FLEE:
			if arrived:
				_hide_left = _settings.hide_time
				_set_state(State.HIDE)
		State.HIDE:
			if alarm:
				_hide_left = _settings.hide_time  # Still there: stay put longer.
			_hide_left -= delta
			if _hide_left <= 0.0:
				if not _loop:
					_next_wander_point()
				_resume()


## The target cannot be reached: a fleeing prey hides where it is, a
## wandering one picks another point.
func give_up() -> void:
	match state:
		State.FLEE:
			_hide_left = _settings.hide_time
			_set_state(State.HIDE)
		State.WANDER:
			_next_wander_point()
		State.SEARCH:
			if goal == Goal.FUSES:
				next_slot()


## Goes for a task of the other objectives (S-018) at a point.
func go_task(point: Vector3, run := false) -> void:
	goal = Goal.TASK
	_task_point = point
	rush = run
	_resume()


## Goes for a goal of the loop: the fuses, the transformer, the exit.
func go_for(new_goal: Goal) -> void:
	goal = new_goal
	rush = false
	_resume()


## Sends the prey to wander from scratch, at a position (after a catch).
func reset(at_index: int) -> void:
	_breath_left = 0.0
	_wander_index = at_index
	_pause_left = _settings.wander_pause
	if not _wander_points.is_empty():
		target = _wander_points[_wander_index]
	_set_state(State.WANDER)


## Where the current goal of the loop is.
func _goal_point() -> Vector3:
	match goal:
		Goal.REPAIR:
			return _transformer_point
		Goal.EXIT:
			return _exit_point
		Goal.TASK:
			return _task_point
	return _slots[slot_index] if not _slots.is_empty() else target


## Back to what it was doing: wandering, or the current goal of the loop.
func _resume() -> void:
	if not _loop:
		_set_state(State.WANDER)
		return
	match goal:
		Goal.FUSES:
			if not _slots.is_empty():
				target = _slots[slot_index]
			_set_state(State.SEARCH)
		Goal.REPAIR:
			target = _transformer_point
			_set_state(State.SEARCH)
		Goal.EXIT:
			target = _exit_point
			_set_state(State.ESCAPE)
		Goal.TASK:
			target = _task_point
			_set_state(State.SEARCH)


## Runs to the hiding spot farthest from the monster. In the game loop, to the
## one nearest its goal among those far enough from the monster (T-060): out of
## reach, but not across the whole map.
func _flee(threat: Vector3) -> void:
	if _hiding_spots.is_empty():
		return
	target = _hiding_spots[MonsterBrain.farthest_index(_hiding_spots, threat)]
	if _loop:
		var goal_at := _goal_point()
		var best := INF
		for spot in _hiding_spots:
			var distance := spot.distance_to(goal_at)
			if spot.distance_to(threat) >= _settings.safe_distance and distance < best:
				best = distance
				target = spot
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
