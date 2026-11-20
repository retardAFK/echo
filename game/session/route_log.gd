class_name RouteLog
extends RefCounted
## The routes of a game (spec S-020, T-339, piste U2): where each player was,
## every sample_time, and where the hunted were caught, for the replay on the
## map of the end screen. Pure logic: RouteWatch records it in solo and on the
## room; the clients get the room's at the end (NetGame, Event.ROUTES).
##
## Track 0 is the monster, track i + 1 the hunted of GameLoop.team[i]. A
## position is on the ground plane (world x, z). Vector2.INF means "not in the
## game then" (not there yet, or out for good): no line is drawn through it.

const MONSTER := 0
## The values of a missing position.
const MISSING := Vector2.INF

## Seconds between two positions; doubles each time the tracks are halved.
var sample_time := 2.0
## One PackedVector2Array per player, all of the same size.
var tracks: Array[PackedVector2Array] = []
## [track, game time, position] of each catch, in order.
var captures: Array = []
## Game time of the last position (the end of the game once it is over).
var end_time := 0.0

var _settings: RouteSettings


func _init(settings: RouteSettings = null) -> void:
	_settings = settings
	if settings != null:
		sample_time = settings.sample_time


## Positions recorded per track.
func size() -> int:
	return 0 if tracks.is_empty() else tracks[0].size()


func is_empty() -> bool:
	return size() == 0


## Adds one position per track, at game time `time`. `points[i]` is the
## position of track i, or MISSING. A track seen for the first time is
## padded with MISSING before.
func record(points: Array[Vector2], time: float) -> void:
	var count := size()
	while tracks.size() < points.size():
		var track := PackedVector2Array()
		for i in count:
			track.append(MISSING)
		tracks.append(track)
	for i in tracks.size():
		tracks[i].append(points[i] if i < points.size() else MISSING)
	end_time = time
	if _settings != null and size() >= _settings.max_points:
		_halve()


## A catch of the hunted of track `track`, at `at`.
func capture(track: int, time: float, at: Vector2) -> void:
	captures.append([track, time, at])


## Game time of position `index`.
func time_of(index: int) -> float:
	return index * sample_time


## Whether the line from position `index - 1` to `index` of a track is drawn:
## both are there and the player did not jump (moved to the prison).
func joined(track: int, index: int) -> bool:
	if index <= 0 or index >= size():
		return false
	var from := tracks[track][index - 1]
	var to := tracks[track][index]
	if not from.is_finite() or not to.is_finite():
		return false
	var speed := _settings.break_speed if _settings != null else 9.0
	return from.distance_to(to) <= speed * sample_time


## Where a player was at game time `time`, between two positions; MISSING if
## it was not in the game then, or jumped between them.
func position_at(track: int, time: float) -> Vector2:
	if is_empty() or time < 0.0:
		return MISSING
	var at := time / sample_time
	var index := mini(int(at), size() - 1)
	var here := tracks[track][index]
	if index + 1 >= size() or not joined(track, index + 1):
		return here
	return here.lerp(tracks[track][index + 1], at - index)


## What the room sends to the clients at the end: [sample_time, tracks,
## captures, end_time].
func values() -> Array:
	return [sample_time, tracks.duplicate(), captures.duplicate(true), end_time]


## The log a client builds from the room's values().
static func from_values(values: Array, settings: RouteSettings = null) -> RouteLog:
	var log := RouteLog.new(settings)
	if values.size() < 4:
		return log
	log.sample_time = values[0]
	for track: PackedVector2Array in values[1]:
		log.tracks.append(track)
	log.captures = values[2]
	log.end_time = values[3]
	return log


## Keeps every other position: half the points, twice the time between two.
func _halve() -> void:
	for i in tracks.size():
		var kept := PackedVector2Array()
		for index in range(0, tracks[i].size(), 2):
			kept.append(tracks[i][index])
		tracks[i] = kept
	sample_time *= 2.0
