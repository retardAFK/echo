class_name DistantSounds
extends Node3D
## Far-off sounds of a building (spec S-014, T-191): while the camera is in
## the box of `size` around the node, now and then one of the streams plays
## some way off, along the building's long axis (local Z), inside the box.
## Plain ambience: it never goes through NoiseBus, so it betrays nobody.

## Size of the box, in meters.
@export var size := Vector3.ONE
@export var streams: Array[AudioStream] = []
## Seconds between two sounds, at random between these.
@export var interval := Vector2(18.0, 40.0)
## How far from the camera they play, at random between these.
@export var distance := Vector2(14.0, 26.0)

var _rng := RandomNumberGenerator.new()
var _wait := 0.0
var _player: AudioStreamPlayer3D


func _ready() -> void:
	_rng.seed = hash(String(name))
	_wait = _rng.randf_range(interval.x, interval.y) / 2.0
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 6.0
	_player.max_distance = distance.y + 10.0
	add_child(_player)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or streams.is_empty() or not contains(camera.global_position):
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(interval.x, interval.y)
	play_near(camera.global_position)


## Plays one of the sounds some way off from a point; returns where.
func play_near(from: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * from
	var half := size / 2.0
	var way := 1.0 if _rng.randf() < 0.5 else -1.0
	var gap := _rng.randf_range(distance.x, distance.y)
	if absf(local.z + way * gap) > half.z:
		way = -way  # The other way, toward the longer side.
	local.z = clampf(local.z + way * gap, -half.z, half.z)
	_player.global_position = global_transform * local
	_player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	_player.play()
	return _player.global_position


## True if a world position lies inside the box.
func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	var half := size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z
