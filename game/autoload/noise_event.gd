class_name NoiseEvent
extends RefCounted
## One noise heard in the world (spec S-002). Pure data, sent by NoiseBus.

## CALL and RESCUE: a captured hunted calling for help, a teammate freeing it
## (S-010, T-107). DOOR: a door opened, closed or smashed (S-016). CAGE: a
## cage's gate opened by a teammate; BELL: the prison's bell; KEYBOARD: a
## hunted at a terminal; CAMERA: the monster smashing a camera; SPEAKER: a
## loudspeaker set off from a terminal; SHUTTER: a metal shutter (S-018).
enum Type {
	FOOTSTEP,
	BREATH,
	CAR_ALARM,
	FUSE,
	REPAIR,
	SIREN,
	THROW,
	IMPACT,
	DECOY,
	HIDE,
	CALL,
	RESCUE,
	DOOR,
	CAGE,
	BELL,
	KEYBOARD,
	CAMERA,
	SPEAKER,
	SHUTTER,
}

var type: Type
## Where the noise starts, in world space.
var position: Vector3
## How far the noise carries in open space, in meters.
var noise_range: float
## The node that made the noise, so listeners can ignore their own noises.
var source: Node
## Engine time of the emission, in milliseconds.
var time_msec: int


func _init(p_type: Type, p_position: Vector3, p_noise_range: float, p_source: Node = null) -> void:
	type = p_type
	position = p_position
	noise_range = p_noise_range
	source = p_source
	time_msec = Time.get_ticks_msec()
