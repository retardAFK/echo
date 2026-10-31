class_name PlayerSettings
extends Resource
## Tunable values for the player movement (spec S-001).
## Every gameplay number lives here, never in the player code.

@export_group("Speeds")
## Walking speed, in m/s.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 3.0
## Sprinting speed, in m/s.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var sprint_speed: float = 5.5
## Crouched speed, in m/s.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var crouch_speed: float = 1.5
## How fast the player reaches the target speed, in m/s².
@export_range(0.1, 200.0, 0.1, "suffix:m/s²") var acceleration: float = 30.0
## How fast the player stops when no key is pressed, in m/s².
@export_range(0.1, 200.0, 0.1, "suffix:m/s²") var deceleration: float = 40.0

@export_group("Look")
## Mouse sensitivity, in degrees per screen pixel.
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity: float = 0.15
## Maximum up and down look angle, in degrees.
@export_range(1.0, 89.9, 0.1, "suffix:°") var pitch_limit: float = 89.0

@export_group("Body")
## Capsule height when standing, in meters.
@export_range(0.5, 3.0, 0.01, "suffix:m") var standing_height: float = 1.75
## Capsule height when crouched, in meters.
@export_range(0.5, 3.0, 0.01, "suffix:m") var crouch_height: float = 1.0
## Capsule radius, in meters.
@export_range(0.1, 1.0, 0.01, "suffix:m") var capsule_radius: float = 0.3
## Distance between the eyes and the top of the capsule, in meters.
@export_range(0.0, 0.5, 0.01, "suffix:m") var eye_offset: float = 0.15
## Time to go from standing to crouched, in seconds.
@export_range(0.01, 1.0, 0.01, "suffix:s") var crouch_transition_time: float = 0.15
## Highest step climbed without jumping, in meters.
@export_range(0.0, 0.6, 0.01, "suffix:m") var max_step_height: float = 0.3

@export_group("Head bob")
## Camera sway while moving. Can be turned off for motion sickness.
@export var head_bob_enabled: bool = true
## Vertical sway when walking, in meters.
@export_range(0.0, 0.2, 0.005, "suffix:m") var head_bob_walk_amplitude: float = 0.03
## Vertical sway when sprinting, in meters.
@export_range(0.0, 0.2, 0.005, "suffix:m") var head_bob_sprint_amplitude: float = 0.06
## Sway cycles per meter travelled (one cycle = two steps).
@export_range(0.05, 2.0, 0.01) var head_bob_cycles_per_meter: float = 0.35
