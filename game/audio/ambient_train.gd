class_name AmbientTrain
extends AudioStreamPlayer3D
## A distant train passing on the embankment now and then (spec S-006, T-050).
## The sound slides along the track while it plays. Like every ambient sound,
## it does not go through NoiseBus: it betrays nobody.
## It covers the noises near the railway for cover_time seconds in the middle
## of its pass (S-020, T-332): NoiseBus asks covers() and marks them masked,
## so the monster neither hears nor sees them. Online, only the room starts
## trains (auto off on a client) and NetGame sends each pass to everyone, so
## the hunted hear the train when it covers them.

## Signals a pass that starts, and which way (from track_start or not).
signal pass_started(forward: bool)

const GROUP := &"trains"

## The track, in local coordinates of the parent: the sound goes from one end
## to the other during the pass, in a random direction.
@export var track_start := Vector3.ZERO
@export var track_end := Vector3.ZERO
## Seconds of silence between two trains.
@export var min_wait := 45.0
@export var max_wait := 110.0
## Seconds before the first train.
@export var first_wait := 15.0

var settings: TrainSettings = preload("res://game/data/train_settings.tres")
## Starts trains on its own; off on an online client, where the room does.
var auto := true
var passes := 0
## Seconds since the current pass started; negative between passes.
var pass_time := -1.0

var _wait := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_wait = first_wait
	position = track_start


func _process(delta: float) -> void:
	if pass_time >= 0.0:
		pass_time += delta
		if pass_time > pass_length():
			pass_time = -1.0
	if playing:
		var length := stream.get_length() if stream else 1.0
		position = _from.lerp(_to, clampf(get_playback_position() / length, 0.0, 1.0))
		return
	if not auto:
		return
	_wait -= delta
	if _wait <= 0.0:
		start_pass()


## Starts a train now, in a random direction, and schedules the next one.
func start_pass() -> void:
	_wait = _rng.randf_range(min_wait, max_wait)
	run_pass(_rng.randf() < 0.5)


## Starts a train now from track_start (forward) or from track_end.
func run_pass(forward: bool) -> void:
	_from = track_start if forward else track_end
	_to = track_end if forward else track_start
	position = _from
	passes += 1
	pass_time = 0.0
	play()
	pass_started.emit(forward)


## Seconds a pass lasts: the length of its sound.
func pass_length() -> float:
	return stream.get_length() if stream else settings.cover_time


## True while the train roars by: cover_time seconds in the middle of a pass.
func is_covering() -> bool:
	if pass_time < 0.0:
		return false
	var start := maxf(0.0, (pass_length() - settings.cover_time) / 2.0)
	return pass_time >= start and pass_time <= start + settings.cover_time


## True if a world position is close enough to the railway to be covered.
func near_track(point: Vector3) -> bool:
	var parent := get_parent() as Node3D
	var a := parent.to_global(track_start) if parent else track_start
	var b := parent.to_global(track_end) if parent else track_end
	var flat := Vector3(point.x, a.y, point.z)
	var closest := Geometry3D.get_closest_point_to_segment(flat, a, b)
	return flat.distance_to(closest) <= settings.cover_distance


## True if a passing train covers a noise at this world position.
static func covers(tree: SceneTree, point: Vector3) -> bool:
	for train: AmbientTrain in tree.get_nodes_in_group(GROUP):
		if train.is_covering() and train.near_track(point):
			return true
	return false
