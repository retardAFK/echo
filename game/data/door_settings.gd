class_name DoorSettings
extends Resource
## Tunable values of the doors that open and close (spec S-016, Q1 to Q3).
## Ranges from section 6.2 of ECHO_PROJET.md, to tune in playtest.

@export_group("Noise")
## Opening or closing a door standing up, in meters (Q1, section 6.2).
@export_range(0.5, 50.0, 0.5, "suffix:m") var open_range: float = 6.0
## Opening or closing it slowly, crouched or prowling, in meters (Q1).
@export_range(0.0, 20.0, 0.5, "suffix:m") var quiet_range: float = 2.0
## The monster smashing it open on the run, in meters (Q2).
@export_range(0.5, 50.0, 0.5, "suffix:m") var smash_range: float = 12.0

## A fire door slamming shut on its own, in meters (Q3).
@export_range(0.5, 50.0, 0.5, "suffix:m") var slam_range: float = 5.0
## An emergency exit's crash bar, in meters (Q3).
@export_range(0.5, 50.0, 0.5, "suffix:m") var emergency_range: float = 10.0
## A shop's metal shutter rolled up or down, in meters (S-016, the gallery).
@export_range(0.5, 50.0, 0.5, "suffix:m") var shutter_range: float = 12.0
## The bell over a shop door, rung by opening it, even slowly, in meters.
@export_range(0.5, 50.0, 0.5, "suffix:m") var bell_range: float = 8.0

@export_group("Timing")
## How long the slow, quiet way takes, in seconds (Q1).
@export_range(0.1, 5.0, 0.1, "suffix:s") var quiet_time: float = 1.0
## A fire door closes on its own this long after it was opened, in seconds (Q3).
@export_range(0.5, 20.0, 0.5, "suffix:s") var fire_close_delay: float = 3.0
## How long the leaf takes to swing, in seconds.
@export_range(0.05, 2.0, 0.05, "suffix:s") var swing_time: float = 0.3

@export_group("Reach")
## Farthest distance from the middle of the doorway to use it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var reach: float = 1.6
## How far ahead the running monster smashes a closed door, in meters (Q2).
@export_range(0.2, 5.0, 0.1, "suffix:m") var smash_reach: float = 1.2
## How far ahead on its way an AI opens a closed door, in meters.
@export_range(0.2, 5.0, 0.1, "suffix:m") var ai_reach: float = 1.5
## The fleeing AI prey closes a door behind it once this far past it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var close_behind_distance: float = 2.0
## Most height between a body and the doorway to use it, in meters.
@export_range(0.2, 5.0, 0.1, "suffix:m") var reach_height: float = 1.2

@export_group("Shape")
## Thickness of the leaf, in meters.
@export_range(0.01, 0.3, 0.01, "suffix:m") var leaf_thickness: float = 0.06
## How far the leaf swings open, in degrees.
@export_range(10.0, 180.0, 1.0, "suffix:°") var open_angle: float = 95.0
## How much of a rolled-up shutter still hangs under the lintel, in meters.
@export_range(0.0, 1.0, 0.05, "suffix:m") var shutter_hang: float = 0.3
