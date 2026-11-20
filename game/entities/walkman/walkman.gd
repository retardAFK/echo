class_name Walkman
extends Node3D
## A walkman the hunted put down (S-020, T-334, piste R3): a decoy that walks.
## After walkman_delay, it plays footsteps that go away from it, straight
## ahead of where the hunted faced (its local -Z), over walkman_path_length,
## stopped before a wall. Each step is a FOOTSTEP noise like a hunted's
## running step, at the step's place: the monster cannot tell them apart. It
## plays once. Online, only the room's walkman steps (mirror on the clients'
## copies, which are only seen): the steps reach them as noises.

signal finished

## Group of the walkmen placed in the world.
const GROUP := &"walkmen"
## The footsteps stop this far before a wall, in meters.
const WALL_MARGIN := 0.5
## Height of the ray that looks for a wall on the way, in meters.
const RAY_HEIGHT := 1.0
## What stops the footsteps: the ground and props, and walls.
const BLOCK_MASK := 1 | NoiseBus.WALLS_COLLISION_MASK

@export var settings: RuseSettings

## A client's copy of the room's walkman: silent, the room plays the steps.
var mirror := false
var steps := 0
var done := false
## Seconds left before the first step.
var delay_left := 0.0
## Meters walked so far along the path, and its length once measured.
var walked := 0.0
var path_length := -1.0

var _next_step := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	RetroSurface.apply_to(self, RetroSurface.DEFAULT_SETTINGS)
	delay_left = settings.walkman_delay


func _physics_process(delta: float) -> void:
	if mirror or done:
		return
	if delay_left > 0.0:
		delay_left -= delta
		return
	if path_length < 0.0:
		path_length = measure_path()
	walked = minf(walked + settings.walkman_speed * delta, path_length)
	while _next_step <= walked:
		_step(_next_step)
		_next_step += settings.walkman_stride
	if walked >= path_length:
		done = true
		finished.emit()


## Where the footsteps go: straight ahead, flat.
func direction() -> Vector3:
	var ahead := -global_basis.z
	ahead.y = 0.0
	return ahead.normalized() if ahead.length() > 0.001 else Vector3.FORWARD


## How far the footsteps can go before a wall, at most walkman_path_length.
func measure_path() -> float:
	var length := settings.walkman_path_length
	if not is_inside_tree():
		return length
	var from := global_position + Vector3.UP * RAY_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, from + direction() * length, BLOCK_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		length = maxf(from.distance_to(hit.position) - WALL_MARGIN, 0.0)
	return length


## The place of the footstep this far along the path, in world space.
func step_position(along: float) -> Vector3:
	return global_position + direction() * along


func _step(along: float) -> void:
	steps += 1
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP, step_position(along), settings.walkman_step_range, self
	)
