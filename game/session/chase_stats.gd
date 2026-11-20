class_name ChaseStats
extends RefCounted
## Chase statistics of a game (spec S-020, T-322, piste E8), for the end
## screen: how many chases, how many successful escapes, how far the monster
## was on average. Pure logic: ChaseWatch gives it the facts on the room or in
## solo, the clients copy the room's figures (NetWorld.clock()).
##
## - A chase of a hunted starts when the monster sees it (line of sight, not
##   hidden, in front of it) within start_range, while it is free.
## - It is a successful escape when the monster has not seen it for
##   escape_time, or when the hunted win the game.
## - It is lost when the hunted is captured, or when the monster wins.
## - The mean distance is the average monster to hunted distance over the
##   time of all chases.

var chase_count := 0
var escape_count := 0
var catch_count := 0

var _settings: ChaseSettings
## Hunted being chased (an id) -> seconds the monster has not seen it.
var _unseen := {}
## Hunted out of the game for good (ids): never chased again.
var _left := {}
var _distance_sum := 0.0
var _chased_time := 0.0
## Client side: the room's mean distance.
var _mirrored_mean := -1.0


func _init(settings: ChaseSettings) -> void:
	_settings = settings


## One look at one hunted, delta seconds after the last one. distance is
## from the monster, seen says whether the monster sees it (ChaseWatch),
## caught whether it is captured or out of the game.
func step(id: int, delta: float, distance: float, seen: bool, caught: bool) -> void:
	if _left.has(id):
		return
	if not _unseen.has(id):
		if seen and not caught and distance <= _settings.start_range:
			_unseen[id] = 0.0
			chase_count += 1
		return
	if caught:
		_unseen.erase(id)
		catch_count += 1
		return
	_distance_sum += distance * delta
	_chased_time += delta
	var in_sight := seen and distance <= _settings.lost_range
	_unseen[id] = 0.0 if in_sight else _unseen[id] + delta
	if _unseen[id] >= _settings.escape_time:
		_unseen.erase(id)
		escape_count += 1


## A hunted is out of the game for good (GameLoop.hunted_out()): its chase,
## if any, is lost, and it is never chased again.
func leave(id: int) -> void:
	if _unseen.erase(id):
		catch_count += 1
	_left[id] = true


## The game is over: the chases still going on end with it.
func finish(hunted_won: bool) -> void:
	if hunted_won:
		escape_count += _unseen.size()
	else:
		catch_count += _unseen.size()
	_unseen.clear()


func is_chased(id: int) -> bool:
	return _unseen.has(id)


## Average monster to hunted distance during the chases, in meters; 0 before
## the first chase.
func mean_distance() -> float:
	if _mirrored_mean >= 0.0:
		return _mirrored_mean
	return _distance_sum / _chased_time if _chased_time > 0.0 else 0.0


## Room side: [chases, escapes, catches, mean distance], sent to the clients.
func values() -> Array:
	return [chase_count, escape_count, catch_count, mean_distance()]


## Client side: the room's figures.
func apply(values: Array) -> void:
	if values.size() < 4:
		return
	chase_count = values[0]
	escape_count = values[1]
	catch_count = values[2]
	_mirrored_mean = values[3]
