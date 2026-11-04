class_name MonsterBrain
extends RefCounted
## Monster state machine (spec S-003), pure logic testable without a scene.
## The scene feeds it what the monster hears and sees each frame, then reads
## back where to go and at which pace.

signal state_changed(state: State)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH }
enum Pace { PROWL, WALK, RUN }

var settings: MonsterSettings
var state := State.PATROL
## Where the monster is heading.
var target := Vector3.ZERO
## Spotting gauge, from 0 (unseen) to 1 (spotted: the chase starts).
var spot_level := 0.0
## Whether the monster reached its target and is looking around.
var lingering := false

var _patrol: Array[Vector3] = []
var _patrol_index := 0
var _timer := 0.0
var _last_seen := Vector3.ZERO


func _init(p_settings: MonsterSettings) -> void:
	settings = p_settings


## Time needed to spot a player at this distance, in seconds.
static func spot_time(distance: float, crouched: bool, p_settings: MonsterSettings) -> float:
	var t := clampf(distance / p_settings.vision_range, 0.0, 1.0)
	var base := lerpf(p_settings.spot_time_near, p_settings.spot_time_far, t)
	return base / p_settings.crouch_spot_factor if crouched else base


## Index of the patrol point farthest from a position (used after a catch).
static func farthest_index(points: Array[Vector3], from: Vector3) -> int:
	var best := 0
	for i in points.size():
		if points[i].distance_to(from) > points[best].distance_to(from):
			best = i
	return best


func set_patrol(points: Array[Vector3], start_index := 0) -> void:
	_patrol = points
	_patrol_index = clampi(start_index, 0, maxi(points.size() - 1, 0))
	_enter(State.PATROL)
	_update_patrol(false)


func get_pace() -> Pace:
	if lingering:
		return Pace.PROWL
	match state:
		State.INVESTIGATE:
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


## Feeds one frame of perception. `arrived` is true when the monster reached its target.
func update(
	delta: float,
	sees_player: bool,
	player_position: Vector3,
	distance: float,
	crouched: bool,
	arrived: bool
) -> void:
	_update_spotting(delta, sees_player, distance, crouched)
	if sees_player:
		_last_seen = player_position
	if state != State.CHASE and spot_level >= 1.0:
		_enter(State.CHASE)
	match state:
		State.PATROL:
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


func _update_patrol(arrived: bool) -> void:
	if _patrol.is_empty():
		return
	if arrived:
		_patrol_index = (_patrol_index + 1) % _patrol.size()
	target = _patrol[_patrol_index]


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
		_enter(State.PATROL)
		_update_patrol(false)


func _enter(new_state: State) -> void:
	var changed := new_state != state
	state = new_state
	_timer = 0.0
	lingering = false
	if changed:
		state_changed.emit(state)
