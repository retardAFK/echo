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
