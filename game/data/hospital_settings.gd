class_name HospitalSettings
extends Resource
## Tunable values for the hospital Saint-Roch (spec S-014). Proposals of the
## spec, to tune in playtest.

@export_group("Monitors (Q6)")
## How far a monitor's beep carries, in meters.
@export_range(1.0, 60.0, 0.5, "suffix:m") var monitor_range: float = 15.0
## How long a monitor beeps once switched on, in seconds.
@export_range(1.0, 60.0, 0.5, "suffix:s") var monitor_time: float = 10.0
## Time between two beeps, in seconds.
@export_range(0.2, 5.0, 0.1, "suffix:s") var monitor_interval: float = 1.0
## Farthest distance from a monitor to switch it on or off, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var monitor_reach: float = 1.8
## Seconds the monster holds "interact" to switch a beeping monitor off.
@export_range(0.1, 5.0, 0.1, "suffix:s") var monitor_off_hold: float = 0.5

@export_group("Gurneys (Q7)")
## Rolling noise of a gurney pushed walking, then running, in meters.
@export_range(0.0, 30.0, 0.5, "suffix:m") var gurney_walk_range: float = 6.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var gurney_run_range: float = 10.0
## Speed above which a pushed gurney rolls as if run, in m/s.
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var gurney_run_speed: float = 3.5
## How far in front of the hunted's feet the gurney's middle rolls, in meters.
@export_range(0.5, 3.0, 0.05, "suffix:m") var gurney_lead: float = 1.4
## Farthest the gurney may lag behind where it should be before it slips
## out of the hunted's hands, in meters.
@export_range(0.2, 3.0, 0.05, "suffix:m") var gurney_slip: float = 1.0
## Farthest distance from a gurney to take it or shove it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var gurney_reach: float = 2.0
## Seconds the monster holds "interact" to shove a gurney aside.
@export_range(0.1, 5.0, 0.1, "suffix:s") var gurney_shove_hold: float = 1.0
## Noise of a gurney shoved over by the monster, in meters.
@export_range(0.0, 30.0, 0.5, "suffix:m") var gurney_shove_range: float = 10.0
## Reach of a monster running into a gurney, which shoves it, in meters.
@export_range(0.5, 3.0, 0.05, "suffix:m") var gurney_run_reach: float = 1.4

@export_group("Wheelchairs (Q7)")
## How far a launched wheelchair rolls, in meters.
@export_range(1.0, 30.0, 0.5, "suffix:m") var wheelchair_distance: float = 8.0
## Speed it is launched at, in m/s: it slows down to stop at wheelchair_distance.
@export_range(1.0, 15.0, 0.5, "suffix:m/s") var wheelchair_speed: float = 5.0
## Its squeak while it rolls, in meters, repeated every roll_interval.
@export_range(0.0, 30.0, 0.5, "suffix:m") var wheelchair_range: float = 8.0
## Farthest distance from a wheelchair to launch it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var wheelchair_reach: float = 1.8

@export_group("Rolling")
## Time between two rolling noises, in seconds.
@export_range(0.1, 3.0, 0.05, "suffix:s") var roll_interval: float = 0.5
