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

@export_group("Timing")
## How long the slow, quiet way takes, in seconds (Q1).
@export_range(0.1, 5.0, 0.1, "suffix:s") var quiet_time: float = 1.0
## How long the leaf takes to swing, in seconds.
@export_range(0.05, 2.0, 0.05, "suffix:s") var swing_time: float = 0.3

@export_group("Reach")
## Farthest distance from the middle of the doorway to use it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var reach: float = 1.6
## How far ahead the running monster smashes a closed door, in meters (Q2).
@export_range(0.2, 5.0, 0.1, "suffix:m") var smash_reach: float = 1.2
## How far ahead on its way an AI opens a closed door, in meters.
@export_range(0.2, 5.0, 0.1, "suffix:m") var ai_reach: float = 1.5
## Most height between a body and the doorway to use it, in meters.
@export_range(0.2, 5.0, 0.1, "suffix:m") var reach_height: float = 1.2

@export_group("Shape")
## Thickness of the leaf, in meters.
@export_range(0.01, 0.3, 0.01, "suffix:m") var leaf_thickness: float = 0.06
## How far the leaf swings open, in degrees.
@export_range(10.0, 180.0, 1.0, "suffix:°") var open_angle: float = 95.0
