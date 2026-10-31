class_name PlayerMotion
extends RefCounted
## Pure movement math for the player (spec S-001), testable without a scene.

enum Gait { CROUCH, WALK, SPRINT }


## Target speed for a gait, in m/s.
static func speed_for_gait(settings: PlayerSettings, gait: Gait) -> float:
	match gait:
		Gait.CROUCH:
			return settings.crouch_speed
		Gait.SPRINT:
			return settings.sprint_speed
	return settings.walk_speed


## Horizontal direction from a 2D input (x = right, y = back) and the body yaw.
## The result never exceeds length 1, so diagonals are not faster.
static func wish_direction(input: Vector2, yaw: float) -> Vector3:
	var flat := input.limit_length(1.0)
	return Vector3(flat.x, 0.0, flat.y).rotated(Vector3.UP, yaw)


## Moves a horizontal velocity toward the target, accelerating or braking.
static func approach_velocity(
	current: Vector3, target: Vector3, settings: PlayerSettings, delta: float
) -> Vector3:
	var rate := settings.acceleration if target.length_squared() > 0.0 else settings.deceleration
	return current.move_toward(target, rate * delta)


## Clamps a pitch angle (radians) to the look limit.
static func clamp_pitch(pitch: float, settings: PlayerSettings) -> float:
	var limit := deg_to_rad(settings.pitch_limit)
	return clampf(pitch, -limit, limit)


## Chooses the gait. A crouched player without headroom stays crouched.
static func resolve_gait(
	wants_crouch: bool, wants_sprint: bool, is_moving: bool, is_crouched: bool, has_headroom: bool
) -> Gait:
	if wants_crouch or (is_crouched and not has_headroom):
		return Gait.CROUCH
	if wants_sprint and is_moving:
		return Gait.SPRINT
	return Gait.WALK


## Capsule height for a gait, in meters.
static func height_for_gait(settings: PlayerSettings, gait: Gait) -> float:
	if gait == Gait.CROUCH:
		return settings.crouch_height
	return settings.standing_height


## Head bob amplitude for a gait, in meters. Crouching does not bob.
static func head_bob_amplitude(settings: PlayerSettings, gait: Gait) -> float:
	if not settings.head_bob_enabled:
		return 0.0
	match gait:
		Gait.WALK:
			return settings.head_bob_walk_amplitude
		Gait.SPRINT:
			return settings.head_bob_sprint_amplitude
	return 0.0


## Camera offset for a head bob phase (radians): a figure-eight sway.
static func head_bob_offset(phase: float, amplitude: float) -> Vector3:
	return Vector3(cos(phase) * amplitude * 0.5, absf(sin(phase)) * amplitude, 0.0)
