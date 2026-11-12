class_name RuseSettings
extends Resource
## Tunable values of the hunted's ruses (spec S-008): bottles to throw, alarm
## clock decoys, hiding spots. Ranges from section 6.2 of ECHO_PROJET.md, to
## tune in playtest.

@export_group("Pickups")
## Most bottles the hunted carries at once (Q1).
@export_range(0, 10) var max_bottles: int = 2
## Most alarm clocks the hunted carries at once (Q3).
@export_range(0, 5) var max_decoys: int = 1
## Farthest distance from a pickup to take it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var pickup_reach: float = 1.8

@export_group("Throw")
## Speed of a thrown bottle, in meters per second (Q2): about 15 m on flat
## ground from the eyes with the lift below.
@export_range(1.0, 50.0, 0.5, "suffix:m/s") var throw_speed: float = 16.5
## Angle added above the look direction when throwing, in degrees.
@export_range(0.0, 45.0, 0.5, "suffix:°") var throw_lift: float = 10.0
## How far ahead of the eyes the bottle leaves the hand, in meters.
@export_range(0.0, 1.0, 0.05, "suffix:m") var throw_hand_offset: float = 0.4
## Range of the throwing or placing gesture, in meters (Q2, Q3).
@export_range(0.0, 10.0, 0.1, "suffix:m") var gesture_range: float = 1.0
## Range of the noise of a bottle breaking, in meters (Q2, section 6.2).
@export_range(0.5, 50.0, 0.5, "suffix:m") var impact_range: float = 8.0
## A bottle that touched nothing after this long breaks where it is, in seconds.
@export_range(0.5, 20.0, 0.5, "suffix:s") var bottle_max_flight: float = 4.0
## How long the glass shards stay on the ground, in seconds.
@export_range(0.0, 300.0, 1.0, "suffix:s") var shards_time: float = 30.0
