class_name PreySettings
extends Resource
## Tunable values for the AI prey the monster hunts in solo tests (spec S-004,
## Q4 and Q5). Its speeds and noises are the hunted's (S-001, S-002).

@export_group("Senses")
## Height of the prey's eyes and ears above its feet, in meters.
@export_range(0.1, 3.0, 0.05, "suffix:m") var ear_height: float = 1.6
## Full width of the prey's field of view, in degrees.
@export_range(10.0, 360.0, 1.0, "suffix:°") var vision_angle: float = 120.0
## How far the prey notices the monster, in meters.
@export_range(1.0, 100.0, 0.5, "suffix:m") var sight_range: float = 15.0
## Time between two line of sight checks, in seconds.
@export_range(0.0, 1.0, 0.01, "suffix:s") var vision_interval: float = 0.1

@export_group("Behaviour")
## Pause at each wander point, in seconds.
@export_range(0.0, 30.0, 0.5, "suffix:s") var wander_pause: float = 2.0
## Time spent crouched and silent in a hiding spot, in seconds.
@export_range(0.0, 120.0, 1.0, "suffix:s") var hide_time: float = 20.0
## Time the prey stays out of breath after it stops running, in seconds.
@export_range(0.0, 60.0, 0.5, "suffix:s") var breathless_time: float = 10.0
## Range of the out of breath panting, in meters: only the scan reveals it.
@export_range(0.0, 10.0, 0.1, "suffix:m") var breath_range: float = 0.5
## Time between two pants, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var breath_interval: float = 1.0
## Time without moving while it should before the prey gives up its target, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var stuck_time: float = 1.5
## Chance that the prey notices the flickering lights of a scan (0 to 1).
@export_range(0.0, 1.0, 0.05) var scan_notice_chance: float = 0.5
## In the game loop, how far from the monster a hiding spot must be for the
## prey to run there rather than to the farthest one, in meters (T-060).
@export_range(0.0, 200.0, 1.0, "suffix:m") var safe_distance: float = 40.0

@export_group("Ruses")
## Detour to take a bottle or an alarm clock lying this close, in meters (S-008, Q9).
@export_range(0.0, 50.0, 0.5, "suffix:m") var pickup_detour: float = 6.0
## Where a thrown bottle should land, away from its goal, in meters (Q9).
@export_range(1.0, 50.0, 0.5, "suffix:m") var throw_distance_min: float = 12.0
@export_range(1.0, 50.0, 0.5, "suffix:m") var throw_distance_max: float = 18.0
## It throws only while the monster is at least this far, in meters: closer,
## it just runs.
@export_range(0.0, 50.0, 0.5, "suffix:m") var throw_safe_distance: float = 8.0
## On its way to repair, it places an alarm clock once this close to the
## transformer, and only if still this far from it, in meters (Q9).
@export_range(1.0, 100.0, 1.0, "suffix:m") var decoy_trigger_distance: float = 30.0
@export_range(0.0, 100.0, 1.0, "suffix:m") var decoy_min_distance: float = 20.0
## Fleeing with the monster this close behind, it drops its firecracker at
## its feet, on the monster's way (S-020, T-312), in meters.
@export_range(0.0, 50.0, 0.5, "suffix:m") var firecracker_drop_distance: float = 10.0
## When it flees, a free hiding spot this close and out of the monster's sight
## is where it runs to, in meters (Q9).
@export_range(0.0, 50.0, 0.5, "suffix:m") var hide_search_radius: float = 10.0
## While it flees, it only turns to a hiding spot found on the way once the
## monster is at least this far, in meters (T-071).
@export_range(0.0, 100.0, 1.0, "suffix:m") var hide_flee_distance: float = 20.0
## While it flees, it swerves to a resting car alarm this close to set it
## off in passing, in meters (Q9, T-071).
@export_range(0.0, 50.0, 0.5, "suffix:m") var car_alarm_detour: float = 15.0
## Time between two looks for something to pick up, in seconds.
@export_range(0.05, 5.0, 0.05, "suffix:s") var pickup_look_interval: float = 0.5

@export_group("Team (S-010, T-101)")
## Online, it goes to free a captured teammate this close, in meters.
@export_range(0.0, 400.0, 1.0, "suffix:m") var rescue_detour: float = 80.0
## It goes there, and stays, only while the monster is at least this far
## from the captured teammate, in meters.
@export_range(0.0, 100.0, 1.0, "suffix:m") var rescue_safe_distance: float = 25.0
## While it looks for fuses, it goes for a fuse dropped this close, in meters
## (the whole cité by default: teammates tell each other), if it is safe.
@export_range(0.0, 400.0, 1.0, "suffix:m") var drop_detour: float = 300.0
