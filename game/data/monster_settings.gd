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
## Time the "caught" screen stays up, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var caught_screen_time: float = 2.0

@export_group("Body")
## Height of the ears and eyes above the feet, in meters.
@export_range(0.1, 5.0, 0.05, "suffix:m") var ear_height: float = 2.0
