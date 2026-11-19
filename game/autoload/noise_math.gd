class_name NoiseMath
extends RefCounted
## Pure noise math (spec S-002), testable without a scene.

## The gauge goes from 0 to this value (spec S-002, Q3).
const GAUGE_MAX := 10.0


## Range of a footstep for a gait, in meters. Metal (S-016, Q9) and puddles
## (S-012, Q4: water doubles a noise) carry farther.
static func range_for_gait(
	settings: NoiseSettings,
	gait: PlayerMotion.Gait,
	surface: FloorSurface.Kind = FloorSurface.Kind.CONCRETE
) -> float:
	var metal := surface == FloorSurface.Kind.METAL
	var puddle := surface == FloorSurface.Kind.PUDDLE
	match gait:
		PlayerMotion.Gait.CROUCH:
			return settings.puddle_crouch_range if puddle else settings.crouch_range
		PlayerMotion.Gait.SPRINT:
			if puddle:
				return settings.puddle_sprint_range
			return settings.metal_sprint_range if metal else settings.sprint_range
	if puddle:
		return settings.puddle_walk_range
	return settings.metal_walk_range if metal else settings.walk_range


## Distance between two footsteps for a gait, in meters.
static func stride_for_gait(settings: NoiseSettings, gait: PlayerMotion.Gait) -> float:
	match gait:
		PlayerMotion.Gait.CROUCH:
			return settings.crouch_stride
		PlayerMotion.Gait.SPRINT:
			return settings.sprint_stride
	return settings.walk_stride


## Range left after crossing walls: each wall multiplies it by wall_factor (Q1).
static func perceived_range(noise_range: float, walls: int, settings: NoiseSettings) -> float:
	var counted := clampi(walls, 0, settings.max_walls_counted)
	return noise_range * pow(settings.wall_factor, counted)


## Whether a listener at this distance, behind these walls, hears the noise.
static func is_heard(
	noise_range: float, distance: float, walls: int, settings: NoiseSettings
) -> bool:
	return distance <= perceived_range(noise_range, walls, settings)


## Gauge level (0 to GAUGE_MAX) shown for a noise of this range.
static func gauge_level(noise_range: float, settings: NoiseSettings) -> float:
	return clampf(noise_range / settings.gauge_full_range * GAUGE_MAX, 0.0, GAUGE_MAX)


## Gauge level after decaying for delta seconds. A full gauge empties in gauge_decay_time.
static func decay_gauge(level: float, delta: float, settings: NoiseSettings) -> float:
	return move_toward(level, 0.0, GAUGE_MAX / settings.gauge_decay_time * delta)
