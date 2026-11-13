class_name LoopSettings
extends Resource
## Tunable values of the game loop (spec S-007): fuses, transformer, siren, exit.

## Fuses to find, each in a different visitable building (Q1).
@export_range(1, 4) var fuse_count: int = 3
## Seconds to hold "interact" on a fuse box to take its fuse (Q2).
@export_range(0.1, 10.0, 0.1, "suffix:s") var pickup_time: float = 2.0
## Range of the metal noise of a fuse box, in meters (Q2).
@export_range(0.5, 50.0, 0.5, "suffix:m") var fuse_noise_range: float = 3.0
## Farthest distance from a fuse box to use it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var fuse_reach: float = 2.0
## Seconds to hold "interact" on the transformer to place one fuse (Q3).
@export_range(0.1, 20.0, 0.1, "suffix:s") var repair_time: float = 4.0
## Range of the noise of a fuse placement, in meters (Q3).
@export_range(0.5, 50.0, 0.5, "suffix:m") var repair_noise_range: float = 8.0
## Time between two repair noises while a fuse is being placed, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var repair_noise_interval: float = 1.5
## Farthest distance from the side of the transformer to use it, in meters.
@export_range(0.1, 5.0, 0.1, "suffix:m") var transformer_reach: float = 1.5
## Share of a placement kept when the hunted lets go before the end (Q3, D-009).
@export_range(0.0, 1.0, 0.05) var kept_on_release: float = 0.5
## How long the siren wails once the transformer is repaired, in seconds (Q4).
@export_range(1.0, 60.0, 0.5, "suffix:s") var siren_time: float = 10.0
## Range of the siren in open space, in meters (Q4): long enough to cross the
## whole cité (310 m corner to corner) through the 4 walls counted at most
## (each one halves it, S-002).
@export_range(10.0, 10000.0, 10.0, "suffix:m") var siren_range: float = 5000.0
## Time between two siren noises, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var siren_noise_interval: float = 2.0
## Seconds the exit grille takes to rise.
@export_range(0.1, 20.0, 0.1, "suffix:s") var gate_open_time: float = 3.0
## Least distance between the start points of two hunted (S-010, T-100).
@export_range(0.0, 200.0, 1.0, "suffix:m") var spawn_spacing: float = 40.0
