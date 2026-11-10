class_name MonsterBrain
extends RefCounted
## Monster state machine (spec S-003), pure logic testable without a scene.
## The scene feeds it what the monster hears and sees each frame, then reads
## back where to go and at which pace.

signal state_changed(state: State)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, GUARD }
enum Pace { PROWL, WALK, RUN }

var settings: MonsterSettings
var state := State.PATROL
## Where the monster is heading.
var target := Vector3.ZERO
## Spotting gauge, from 0 (unseen) to 1 (spotted: the chase starts).
var spot_level := 0.0
## Whether the monster reached its target and is looking around.
var lingering := false
## Once the exit is open (S-007, Q4), it guards the tunnel instead of patrolling.
var guarding := false
## Seconds left before it leaves its watch at the tunnel for a round of patrol,
## or before it comes back to it (0 when the exit is shut).
var watch_left := 0.0
## Where it last heard a noise in a building (S-007, Q10), and how many
## seconds it still remembers it.
var lure := Vector3.ZERO
var lure_left := 0.0
## Whether it left its patrol to have a look at the lure.
var on_detour := false

var _patrol: Array[Vector3] = []
var _patrol_index := 0
var _timer := 0.0
var _last_seen := Vector3.ZERO
var _points_since_detour := 0
var _route: Array[Vector3] = []
var _guard_points: Array[Vector3] = []


func _init(p_settings: MonsterSettings) -> void:
	settings = p_settings


## Time needed to spot a player at this distance, in seconds.
static func spot_time(distance: float, crouched: bool, p_settings: MonsterSettings) -> float:
	var t := clampf(distance / p_settings.vision_range, 0.0, 1.0)
	var base := lerpf(p_settings.spot_time_near, p_settings.spot_time_far, t)
	return base / p_settings.crouch_spot_factor if crouched else base


## Movement speed for a pace, in meters per second.
static func speed_for(pace: Pace, p_settings: MonsterSettings) -> float:
	match pace:
		Pace.WALK:
			return p_settings.walk_speed
		Pace.RUN:
			return p_settings.run_speed
	return p_settings.prowl_speed


## Footstep noise range for a pace, in meters (D-009).
static func noise_range_for(pace: Pace, p_settings: MonsterSettings) -> float:
	match pace:
		Pace.WALK:
			return p_settings.walk_range
		Pace.RUN:
			return p_settings.run_range
	return p_settings.prowl_range


## Index of the patrol point farthest from a position (used after a catch).
static func farthest_index(points: Array[Vector3], from: Vector3) -> int:
	var best := 0
	for i in points.size():
		if points[i].distance_to(from) > points[best].distance_to(from):
			best = i
	return best


func set_patrol(points: Array[Vector3], start_index := 0) -> void:
	_patrol = points
	_route = points
	_patrol_index = clampi(start_index, 0, maxi(points.size() - 1, 0))
	_enter(State.PATROL)
	_update_patrol(false)


func get_pace() -> Pace:
	if lingering:
		return Pace.PROWL
	match state:
		State.INVESTIGATE, State.GUARD:
			return Pace.WALK
		State.CHASE, State.SEARCH:
			return Pace.RUN
	return Pace.PROWL


func is_catch_distance(distance: float) -> bool:
	return distance <= settings.catch_distance


## A noise reached the monster's ears. Ignored during a chase.
func hear(position: Vector3) -> void:
	if state == State.CHASE:
		return
	_enter(State.INVESTIGATE)
	target = position


## A noise came from inside a building: the monster will come back and have a
## look there now and then while it patrols (S-007, Q10).
func remember(position: Vector3) -> void:
	lure = position
	lure_left = settings.lure_memory_time


## The exit is open (S-007, Q4): from now on it walks between the guard points
## at the tunnel instead of patrolling. A chase goes on first. Its watch lasts
## guard_time, then it patrols for guard_break and comes back (T-060).
func guard(points: Array[Vector3]) -> void:
	if points.is_empty():
		return
	_guard_points = points
	_start_watch()


func _start_watch() -> void:
	guarding = true
	watch_left = settings.guard_time
	_patrol = _guard_points
	_patrol_index = 0
	on_detour = false
	if state != State.CHASE:
		_enter(State.GUARD)
		_update_patrol(false)


## A round of patrol away from the tunnel, so that it can be slipped past.
func _leave_watch() -> void:
	guarding = false
	watch_left = settings.guard_break
	_patrol = _route if not _route.is_empty() else _guard_points
	_patrol_index = 0
	if state == State.GUARD:
		_enter(State.PATROL)
		_update_patrol(false)


func _update_watch(delta: float) -> void:
	if _guard_points.is_empty() or settings.guard_time <= 0.0:
		return
	watch_left -= delta
	if watch_left > 0.0:
		return
	if guarding:
		_leave_watch()
	else:
		_start_watch()


## Feeds one frame of perception. `arrived` is true when the monster reached its target.
func update(
	delta: float,
	sees_player: bool,
	player_position: Vector3,
	distance: float,
	crouched: bool,
	arrived: bool
) -> void:
	lure_left = maxf(lure_left - delta, 0.0)
	_update_watch(delta)
	_update_spotting(delta, sees_player, distance, crouched)
	if sees_player:
		_last_seen = player_position
	if state != State.CHASE and spot_level >= 1.0:
		_enter(State.CHASE)
	match state:
		State.PATROL, State.GUARD:
			_update_patrol(arrived)
		State.INVESTIGATE:
			_linger_then_patrol(delta, arrived, settings.investigate_time)
		State.CHASE:
			_update_chase(delta, sees_player)
		State.SEARCH:
			_linger_then_patrol(delta, arrived, settings.search_time)


func _update_spotting(delta: float, sees_player: bool, distance: float, crouched: bool) -> void:
	if sees_player:
		spot_level += delta / spot_time(distance, crouched, settings)
	else:
		spot_level -= delta / settings.spot_decay_time
	spot_level = clampf(spot_level, 0.0, 1.0)


## Walks from point to point. On patrol, every few points it makes a detour to
## the building it last heard a noise in, while it remembers it.
func _update_patrol(arrived: bool) -> void:
	if _patrol.is_empty():
		return
	if arrived:
		if on_detour:
			on_detour = false
		else:
			_patrol_index = (_patrol_index + 1) % _patrol.size()
			_points_since_detour += 1
			if (
				state == State.PATROL
				and lure_left > 0.0
				and _points_since_detour >= settings.lure_every
			):
				on_detour = true
				_points_since_detour = 0
	target = lure if on_detour else _patrol[_patrol_index]


func _update_chase(delta: float, sees_player: bool) -> void:
	target = _last_seen
	if sees_player:
		_timer = 0.0
		return
	_timer += delta
	if _timer >= settings.lose_sight_time:
		_enter(State.SEARCH)
		target = _last_seen


func _linger_then_patrol(delta: float, arrived: bool, duration: float) -> void:
	if arrived:
		lingering = true
	if not lingering:
		return
	_timer += delta
	if _timer >= duration:
		_enter(State.GUARD if guarding else State.PATROL)
		_update_patrol(false)


func _enter(new_state: State) -> void:
	var changed := new_state != state
	state = new_state
	_timer = 0.0
	lingering = false
	if changed:
		state_changed.emit(state)
