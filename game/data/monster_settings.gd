class_name MonsterSettings
extends Resource
## Tunable values for the monster (spec S-003, decisions D-008 and D-009).
## Starting values come from the S-003 clarifications, to tune in playtest.

@export_group("Speeds")
## Speed while prowling on patrol or searching around, in meters per second.
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var prowl_speed: float = 1.5
## Speed while walking to a noise, in meters per second.
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var walk_speed: float = 3.5
## Speed while running after the player, in meters per second.
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var run_speed: float = 6.0

@export_group("Own noise (D-009)")
## Footstep range while prowling, in meters. 0 means silent.
@export_range(0.0, 50.0, 0.1, "suffix:m") var prowl_range: float = 0.0
## Footstep range while walking, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var walk_range: float = 3.0
## Footstep range while running, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var run_range: float = 12.0
## Distance between two footsteps, in meters.
@export_range(0.1, 5.0, 0.05, "suffix:m") var stride: float = 1.1
## Breath range, in meters.
@export_range(0.0, 50.0, 0.1, "suffix:m") var breath_range: float = 2.0
## Time between two breaths, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var breath_interval: float = 1.0

@export_group("Vision")
## Full width of the field of view, in degrees.
@export_range(10.0, 360.0, 1.0, "suffix:°") var vision_angle: float = 100.0
## How far the monster sees, in meters.
@export_range(1.0, 100.0, 0.5, "suffix:m") var vision_range: float = 25.0
## Time to spot a standing player right next to the monster, in seconds.
@export_range(0.05, 10.0, 0.05, "suffix:s") var spot_time_near: float = 0.4
## Time to spot a standing player at the edge of vision range, in seconds.
@export_range(0.05, 10.0, 0.05, "suffix:s") var spot_time_far: float = 1.5
## Spotting speed multiplier for a crouched player (0.5 = twice as slow).
@export_range(0.05, 1.0, 0.05) var crouch_spot_factor: float = 0.5
## Time for a full spotting gauge to empty once the player is out of sight, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var spot_decay_time: float = 2.0
## Time between two line of sight checks, in seconds.
@export_range(0.0, 1.0, 0.01, "suffix:s") var vision_interval: float = 0.1

@export_group("Behaviour")
## Time spent looking around where a noise came from, in seconds.
@export_range(0.0, 60.0, 0.5, "suffix:s") var investigate_time: float = 6.0
## Turning speed while looking around after reaching a noise or a last seen spot.
@export_range(0.0, 720.0, 5.0, "suffix:°/s") var look_around_speed: float = 90.0
## Time without seeing the player before a chase turns into a search, in seconds.
@export_range(0.1, 30.0, 0.1, "suffix:s") var lose_sight_time: float = 3.0
## Time spent looking around where the player was last seen, in seconds.
@export_range(0.0, 60.0, 0.5, "suffix:s") var search_time: float = 8.0
## Distance at which the monster catches the player, in meters.
@export_range(0.1, 5.0, 0.1, "suffix:m") var catch_distance: float = 1.2
## How long the monster remembers the building it heard a noise in, in seconds (S-007, Q10).
@export_range(0.0, 600.0, 5.0, "suffix:s") var lure_memory_time: float = 120.0
## Patrol points between two detours to that building.
@export_range(1, 20) var lure_every: int = 3
## Time the "caught" screen stays up, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var caught_screen_time: float = 2.0

@export_group("Body")
## Height of the ears and eyes above the feet, in meters.
@export_range(0.1, 5.0, 0.05, "suffix:m") var ear_height: float = 2.0

@export_group("Noise markers (S-004)")
## Time for a noise marker to fade out, in seconds (D-008).
@export_range(0.1, 10.0, 0.1, "suffix:s") var marker_fade_time: float = 3.0
## Markers shown at once; the oldest is reused when they are all taken.
@export_range(1, 64) var marker_count: int = 12
## Radius of a marker ring on screen, in pixels of the 640 x 360 view.
@export_range(1.0, 40.0, 0.5, "suffix:px") var marker_radius: float = 5.0

@export_group("Building scan (D-009)")
## Total scan time when the gauge is full, in seconds.
@export_range(0.5, 60.0, 0.5, "suffix:s") var scan_capacity: float = 8.0
## Time for an empty gauge to fill up again, in seconds.
@export_range(1.0, 300.0, 1.0, "suffix:s") var scan_recharge_time: float = 45.0
## Lowest gauge level a scan can start from (0.25 = 25 %).
@export_range(0.0, 1.0, 0.05) var scan_min_start: float = 0.25
## Concentration before the building can be heard, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var scan_focus_time: float = 1.0
## Farthest building that can be aimed at, in meters.
@export_range(1.0, 200.0, 1.0, "suffix:m") var scan_max_distance: float = 30.0
## Light flickers per second in a scanned building, the hunted's discreet warning.
@export_range(0.5, 30.0, 0.5, "suffix:/s") var light_flicker_rate: float = 8.0
## Dimmest a flickering light gets, as a share of its normal energy.
@export_range(0.0, 1.0, 0.05) var light_flicker_min: float = 0.15
## Colour of the scan gauge. Pale, never orange (reserved for noise).
@export var scan_bar_color: Color = Color(0.85, 0.88, 0.9)

@export_group("Debug")
## Colour of the field of view outline shown with F4. Never orange (reserved for noise).
@export var debug_cone_color: Color = Color(0.8, 0.85, 0.9)
