class_name NoiseEvent
extends RefCounted
## One noise heard in the world (spec S-002). Pure data, sent by NoiseBus.

## CALL and RESCUE: a captured hunted calling for help, a teammate freeing it
## (S-010, T-107). DOOR: a door opened, closed or smashed (S-016). CAGE: a
## cage's gate opened by a teammate; BELL: the prison's bell; KEYBOARD: a
## hunted at a terminal; CAMERA: the monster smashing a camera; SPEAKER: a
## loudspeaker set off from a terminal; SHUTTER: a metal shutter; DISK: a
## download's hard disk; BEEP: a wrong code; SWITCH: a relay switch (S-018).
## MONITOR: a hospital monitor beeping; ROLL: a gurney or a wheelchair
## rolling, or a gurney shoved over (S-014). GROWL: the monster breaking into a
## run; SCREAM: the monster's cry when it catches a hunted (S-012, T-145).
## FIRECRACKER: a firecracker going off under the monster (S-020, T-312).
## CANS: a can wire yanked by the monster passing (S-020, T-333).
## New types go last: their numbers travel online.
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
	DISK,
	BEEP,
	SWITCH,
	MONITOR,
	ROLL,
	GROWL,
	SCREAM,
	FIRECRACKER,
	CANS,
	SHOT,  # S-024, T-372: a Versus shot.
}

var type: Type
## Where the noise starts, in world space.
var position: Vector3
## How far the noise carries in open space, in meters.
var noise_range: float
## The node that made the noise, so listeners can ignore their own noises.
var source: Node
## Lost in the roar of a ventilation zone (S-014, Q5): the monster and its
## scan do not hear it; the hunted still do.
var masked := false
## Made by the monster (S-012, Q6): the ears play its scrape and its breath.
## Online, the room's message carries it, since a client's copy has no source.
var by_monster := false
## Engine time of the emission, in milliseconds.
var time_msec: int


func _init(p_type: Type, p_position: Vector3, p_noise_range: float, p_source: Node = null) -> void:
	type = p_type
	position = p_position
	noise_range = p_noise_range
	source = p_source
	time_msec = Time.get_ticks_msec()
