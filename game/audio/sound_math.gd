class_name SoundMath
extends RefCounted
## Pure math of how a game sound is heard (spec S-012, T-142): louder near
## its source, quieter at the edge of its range, quieter and muffled behind
## walls, a little duller behind the listener. Testable without a scene.

## Below this, a sound is not played at all.
const SILENT_DB := -80.0


## Volume for the distance alone: 0 dB at the source, edge_db at the edge of
## the perceived range, SILENT_DB beyond it.
static func distance_db(distance: float, perceived_range: float, audio: AudioSettings) -> float:
	if perceived_range <= 0.0 or distance > perceived_range:
		return SILENT_DB
	return audio.edge_db * clampf(distance / perceived_range, 0.0, 1.0)


## Volume lost through walls.
static func wall_db(walls: int, audio: AudioSettings) -> float:
	return audio.wall_db * maxi(walls, 0)


## Volume lost by a sound behind the listener: none in front or to the side,
## behind_db right behind.
static func behind_db(to_sound: Vector3, forward: Vector3, audio: AudioSettings) -> float:
	if to_sound.is_zero_approx() or forward.is_zero_approx():
		return 0.0
	var facing := forward.normalized().dot(to_sound.normalized())
	return audio.behind_db * clampf(-facing, 0.0, 1.0)


## Whole volume of a sound of this range, at this distance, behind these
## walls (the rule of NoiseBus, S-002), in this direction from the listener.
static func gain_db(
	distance: float,
	noise_range: float,
	walls: int,
	to_sound: Vector3,
	forward: Vector3,
	audio: AudioSettings,
	noise: NoiseSettings
) -> float:
	var perceived := NoiseMath.perceived_range(noise_range, walls, noise)
	var db := distance_db(distance, perceived, audio)
	if db <= SILENT_DB:
		return SILENT_DB
	return db + wall_db(walls, audio) + behind_db(to_sound, forward, audio)


## Path of the muffled version of a sound file: foo.wav -> foo_muffled.wav.
static func muffled_path(path: String) -> String:
	if path.is_empty():
		return ""
	return "%s_muffled.%s" % [path.get_basename(), path.get_extension()]


## Volume of one's own noise of this range (a footstep, a breath): louder for
## a noise that carries farther.
static func self_db(noise_range: float, walk_range: float, audio: AudioSettings) -> float:
	if noise_range <= 0.0 or walk_range <= 0.0:
		return SILENT_DB
	var doublings := log(noise_range / walk_range) / log(2.0)
	return clampf(
		audio.self_walk_db + audio.self_db_per_doubling * doublings,
		audio.self_min_db,
		audio.self_max_db
	)
