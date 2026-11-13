class_name NoiseSettings
extends Resource
## Tunable values for the noise system (spec S-002).
## Starting ranges come from section 6.2 of ECHO_PROJET.md, to tune in playtest.

@export_group("Footstep ranges")
## Range of a crouched footstep, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var crouch_range: float = 1.0
## Range of a walking footstep, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var walk_range: float = 4.0
## Range of a sprinting footstep, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var sprint_range: float = 14.0

@export_group("Strides")
## Distance between two crouched footsteps, in meters.
@export_range(0.1, 3.0, 0.05, "suffix:m") var crouch_stride: float = 0.5
## Distance between two walking footsteps, in meters.
@export_range(0.1, 3.0, 0.05, "suffix:m") var walk_stride: float = 0.7
## Distance between two sprinting footsteps, in meters.
@export_range(0.1, 3.0, 0.05, "suffix:m") var sprint_stride: float = 0.9

@export_group("Walls")
## Each wall between a noise and a listener multiplies the range by this factor.
@export_range(0.0, 1.0, 0.05) var wall_factor: float = 0.5
## Walls beyond this count are ignored (keeps raycasts cheap).
@export_range(0, 10) var max_walls_counted: int = 4

@export_group("Capture (S-010, T-107)")
## Range of the call for help of a captured hunted, in meters.
@export_range(0.0, 50.0, 0.5, "suffix:m") var call_range: float = 8.0
## Time between two calls for help, in seconds.
@export_range(0.5, 20.0, 0.5, "suffix:s") var call_interval: float = 3.0
## Range of the noise of a rescue, in meters.
@export_range(0.0, 50.0, 0.5, "suffix:m") var rescue_range: float = 15.0

@export_group("Gauge")
## Noise range that fills the gauge, in meters.
@export_range(1.0, 50.0, 0.5, "suffix:m") var gauge_full_range: float = 15.0
## Time for a full gauge to empty, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var gauge_decay_time: float = 2.0

@export_group("Debug")
## How long a noise ring stays on screen, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var debug_ring_lifetime: float = 3.0
## How long a test probe stays lit after hearing a noise, in seconds.
@export_range(0.1, 5.0, 0.1, "suffix:s") var debug_probe_flash_time: float = 1.0
## Colour of noise in every debug and HUD element. Orange is reserved for noise (2.3).
@export var noise_color: Color = Color(1.0, 0.55, 0.1)
## Height of the noise origin above the feet, in meters.
@export_range(0.0, 2.0, 0.05, "suffix:m") var emit_height: float = 0.3
