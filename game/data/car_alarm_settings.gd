class_name CarAlarmSettings
extends Resource
## Tunable values for the car alarms of the cité (spec S-006, T-042).
## The range comes from section 6.2 of ECHO_PROJET.md, to tune in playtest.

## How far the alarm carries in open space, in meters.
@export_range(1.0, 100.0, 0.5, "suffix:m") var alarm_range: float = 30.0
## How long the alarm rings once set off, in seconds.
@export_range(0.5, 60.0, 0.5, "suffix:s") var ring_time: float = 12.0
## Time between two alarm noises while it rings, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var noise_interval: float = 1.0
## Time after the alarm stops before it can be set off again, in seconds.
@export_range(0.0, 300.0, 1.0, "suffix:s") var rest_time: float = 45.0
## Farthest distance from the car's center to set it off, in meters.
@export_range(0.5, 10.0, 0.1, "suffix:m") var trigger_distance: float = 3.0
## Hazard lights blinks per second while it rings.
@export_range(0.1, 10.0, 0.1, "suffix:Hz") var flash_rate: float = 2.0
## Energy of the hazard lights when lit.
@export_range(0.0, 10.0, 0.1) var flash_energy: float = 1.5
