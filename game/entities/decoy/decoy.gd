class_name Decoy
extends Node3D
## An alarm clock the hunted placed on the ground (spec S-008, Q3): it ticks
## quietly (heard by whoever stands on it, not by NoiseBus), then rings with a
## DECOY noise of 12 m every second, which draws the monster there. The
## monster crushes it by walking on it (Q4): it stops for good.

signal ringing_started
signal crushed

## Group of the alarm clocks placed in the world, for the monsters.
const GROUP := &"decoys"

@export var settings: RuseSettings

var timer: DecoyTimer

@onready var _tick: AudioStreamPlayer3D = $Tick
@onready var _ring: AudioStreamPlayer3D = $Ring
@onready var _crush: AudioStreamPlayer3D = $Crush


## Crushes every ringing alarm clock within this flat distance of a position
## (the monster's feet, Q4). Returns how many it crushed.
static func crush_near(tree: SceneTree, at: Vector3, distance: float) -> int:
	var count := 0
	for node in tree.get_nodes_in_group(GROUP):
		var decoy := node as Decoy
		if decoy == null or not decoy.is_ringing():
			continue
		var gap := decoy.global_position - at
		if Vector2(gap.x, gap.z).length() <= distance and decoy.crush():
			count += 1
	return count


func _ready() -> void:
	add_to_group(GROUP)
	timer = DecoyTimer.new(settings)
	_tick.max_distance = settings.tick_sound_distance
	_ring.max_distance = settings.ring_sound_distance
	_crush.max_distance = settings.ring_sound_distance
	_tick.play()


func is_ringing() -> bool:
	return timer.state == DecoyTimer.State.RINGING


func _physics_process(delta: float) -> void:
	var before := timer.state
	var noise_due := timer.update(delta)
	if before == DecoyTimer.State.TICKING and timer.state == DecoyTimer.State.RINGING:
		_tick.stop()
		_ring.play()
		ringing_started.emit()
	elif before == DecoyTimer.State.RINGING and timer.state == DecoyTimer.State.DONE:
		_ring.stop()
	if noise_due:
		NoiseBus.emit_noise(
			NoiseEvent.Type.DECOY, global_position + Vector3.UP * 0.2, settings.decoy_range, self
		)


## Silences it for good. Returns whether it was still going.
func crush() -> bool:
	if not timer.crush():
		return false
	_tick.stop()
	_ring.stop()
	_crush.play()
	crushed.emit()
	return true
