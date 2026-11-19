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
## Alarm clocks lying in the cité each game, drawn among their places (Q3).
@export_range(0, 20) var decoys_per_game: int = 4
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

@export_group("Decoy")
## Time between placing an alarm clock and its ringing, in seconds (Q3).
@export_range(0.0, 120.0, 0.5, "suffix:s") var decoy_delay: float = 15.0
## The other delay the hunted can choose with the mouse wheel, for a chase
## (S-020, T-313, piste R2), in seconds.
@export_range(0.0, 120.0, 0.5, "suffix:s") var decoy_short_delay: float = 5.0
## How long an alarm clock rings, in seconds (Q3).
@export_range(0.5, 120.0, 0.5, "suffix:s") var decoy_ring_time: float = 10.0
## Range of the ringing in open space, in meters (Q3).
@export_range(0.5, 100.0, 0.5, "suffix:m") var decoy_range: float = 12.0
## Time between two ringing noises, in seconds (Q3).
@export_range(0.1, 10.0, 0.1, "suffix:s") var decoy_noise_interval: float = 1.0
## How far in front of the hunted an alarm clock is placed, in meters.
@export_range(0.0, 3.0, 0.1, "suffix:m") var decoy_place_distance: float = 0.8
## The ticking and ringing are played this far for the ears, in meters: the
## ticking only for the one who stands on it (Q3).
@export_range(0.1, 10.0, 0.1, "suffix:m") var tick_sound_distance: float = 1.5
@export_range(1.0, 100.0, 1.0, "suffix:m") var ring_sound_distance: float = 40.0

@export_group("Firecracker")
## Firecrackers each hunted carries at the start, and at most (S-020, T-312,
## piste R1): no pickup in the cité, one per game.
@export_range(0, 5) var start_firecrackers: int = 1
@export_range(0, 5) var max_firecrackers: int = 1
## Seconds after placing before it can go off, to step away from it.
@export_range(0.0, 10.0, 0.1, "suffix:s") var firecracker_arm_time: float = 1.5
## A monster this close (flat distance to its feet) sets it off, in meters.
@export_range(0.1, 5.0, 0.1, "suffix:m") var firecracker_trigger_distance: float = 1.5
## How long the monster hears nothing after it went off, in seconds (piste R1).
@export_range(0.0, 30.0, 0.5, "suffix:s") var deafen_time: float = 6.0
## Range of the crack's noise for the hunted, in meters, and how far it is
## played for the ears.
@export_range(0.5, 100.0, 0.5, "suffix:m") var firecracker_range: float = 25.0
@export_range(1.0, 100.0, 1.0, "suffix:m") var firecracker_sound_distance: float = 50.0

@export_group("Hiding spots")
## Seconds to hold "interact" to get in, get out, or open a hiding spot (Q5, Q7).
@export_range(0.1, 10.0, 0.1, "suffix:s") var hide_time: float = 1.0
## Range of the door or lid noise, in meters (Q5, Q7).
@export_range(0.5, 50.0, 0.5, "suffix:m") var hide_noise_range: float = 3.0
## The monster opening an empty hiding spot: a noise of at least this range,
## and it stands there this long (S-020, T-310, piste H1): searching at random
## costs something.
@export_range(0.0, 50.0, 0.5, "suffix:m") var empty_search_range: float = 4.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var empty_search_stagger: float = 1.0
## Farthest distance from the front of a hiding spot to use it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var hide_reach: float = 1.6
## How far the hidden one can turn their head from straight out, in degrees (Q6).
@export_range(0.0, 180.0, 1.0, "suffix:°") var hidden_yaw_limit: float = 40.0
@export_range(0.0, 89.0, 1.0, "suffix:°") var hidden_pitch_limit: float = 20.0
## Share of the screen height left visible through the slit (Q6).
@export_range(0.05, 1.0, 0.05) var slit_share: float = 0.3

@export_group("Hiding spot families")
## Low spots, under a bed, a stage, a car (S-016, Q6): slow in and out, quiet.
@export_range(0.1, 10.0, 0.1, "suffix:s") var low_hide_time: float = 2.0
@export_range(0.0, 50.0, 0.5, "suffix:m") var low_noise_range: float = 1.0
## Makeshift spots, behind a curtain or boxes (Q6): quick and silent, but a
## monster this close looking at it sees the hunted.
@export_range(0.1, 10.0, 0.1, "suffix:s") var makeshift_hide_time: float = 0.5
@export_range(0.0, 50.0, 0.5, "suffix:m") var makeshift_noise_range: float = 0.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var makeshift_reveal_distance: float = 2.0
## Metal spots, a dryer, a car boot, a lift (Q6): loud to get in, slow to open.
@export_range(0.0, 50.0, 0.5, "suffix:m") var metal_noise_range: float = 6.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var metal_open_time: float = 2.0
