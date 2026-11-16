class_name PrisonSettings
extends Resource
## Tunable values of the prison (spec S-018, part A, Q2 to Q6). Proposals of
## the spec, to tune in playtest.

@export_group("Stays")
## Seconds before a hunted in a cage is out, its first time there (Q5).
@export_range(5.0, 600.0, 5.0, "suffix:s") var first_stay: float = 120.0
## Seconds before it is out, its second time there (Q5).
@export_range(5.0, 600.0, 5.0, "suffix:s") var second_stay: float = 60.0
## Caught this many times, a hunted is out at once (Q5).
@export_range(2, 10) var catches_out: int = 3
## A cage's clock stops while the monster is closer than this, in meters (Q6).
@export_range(0.0, 100.0, 1.0, "suffix:m") var guard_distance: float = 15.0
## Seconds of black screen after the catch, before the cage (Q2).
@export_range(0.0, 10.0, 0.1, "suffix:s") var jail_delay: float = 2.0

@export_group("Lamp")
## The lamp over a cage blinks in its last seconds, in seconds (Q5).
@export_range(0.0, 120.0, 1.0, "suffix:s") var blink_time: float = 20.0
## One blink, on then off, in seconds.
@export_range(0.1, 5.0, 0.1, "suffix:s") var blink_period: float = 0.8

@export_group("Freeing")
## Holding "interact" on a cage's grille to open it, in seconds (Q3).
@export_range(0.5, 30.0, 0.5, "suffix:s") var free_time: float = 4.0
## The grille creaking at the start and the end, in meters (Q3).
@export_range(0.0, 50.0, 0.5, "suffix:m") var free_range: float = 8.0
## How far from the grille's middle a teammate frees it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var free_reach: float = 1.5
## The guard's terminal: seconds at the keyboard to open every cage (Q4).
@export_range(1.0, 60.0, 0.5, "suffix:s") var guard_time: float = 10.0
## The prison's bell when the guard's terminal opens the cages, in meters (Q4).
@export_range(0.0, 60.0, 0.5, "suffix:m") var bell_range: float = 15.0
