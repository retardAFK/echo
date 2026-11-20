class_name Firecracker
extends Node3D
## A firecracker the hunted placed on the ground (S-020, T-312, piste R1). Once
## armed, it goes off when a monster walks over it: a loud crack, heard far by
## the hunted, and the monster is deafened for deafen_time (Deafness). It is
## the hunted's one answer to the monster's ears. Online, only the room sets
## it off; the clients' copies only play the crack.
## Set in an empty hiding spot (T-331, piste R6), it is a trap: hidden in it,
## stepping near never sets it off, only the monster opening the spot does.

signal burst

## Group of the firecrackers placed in the world, for the monsters.
const GROUP := &"firecrackers"

@export var settings: RuseSettings

## Seconds before it can go off, so the one who placed it can step away.
var arm_left := 0.0
var done := false
## Set as a trap in a hiding spot (T-331): unseen, and only the spot sets it off.
var in_spot := false

@onready var _crack: AudioStreamPlayer3D = $Crack
@onready var _model: Node3D = $Model


## Sets off every armed firecracker within trigger distance of a monster's
## feet and deafens that monster. Returns how many went off.
static func burst_near(monster: Node3D) -> int:
	var count := 0
	for node in monster.get_tree().get_nodes_in_group(GROUP):
		var firecracker := node as Firecracker
		if firecracker == null or not firecracker.is_armed():
			continue
		var gap := firecracker.global_position - monster.global_position
		if Vector2(gap.x, gap.z).length() <= firecracker.settings.firecracker_trigger_distance:
			firecracker.go_off(monster)
			count += 1
	return count


func _ready() -> void:
	add_to_group(GROUP)
	RetroSurface.apply_to(self, RetroSurface.DEFAULT_SETTINGS)
	arm_left = settings.firecracker_arm_time
	_crack.max_distance = settings.firecracker_sound_distance
	_model.visible = not in_spot


func _physics_process(delta: float) -> void:
	arm_left = maxf(arm_left - delta, 0.0)


func is_armed() -> bool:
	return not done and not in_spot and arm_left <= 0.0


## Goes off: deafens monster (if any) first, so it does not hear its own crack,
## then the crack's noise, heard by the hunted. Returns whether it was still there.
func go_off(monster: Node = null) -> bool:
	if done:
		return false
	done = true
	if monster != null and "deafness" in monster and monster.deafness is Deafness:
		(monster.deafness as Deafness).deafen(settings.deafen_time)
	_model.visible = false
	SoundSpace.play(_crack)
	if monster != null:
		NoiseBus.emit_noise(
			NoiseEvent.Type.FIRECRACKER,
			global_position + Vector3.UP * 0.2,
			settings.firecracker_range,
			self
		)
	burst.emit()
	get_tree().create_timer(_crack.stream.get_length() + 0.2).timeout.connect(queue_free)
	return true
