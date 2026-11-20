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
## How long "Le monstre s'énerve" stays on the hunted's screen when the
## monster rises a stage (S-023, Q6), in seconds.
@export_range(0.5, 10.0, 0.5, "suffix:s") var rise_message_time: float = 3.0
## Loudness of the growl heard then, in dB.
@export_range(-40.0, 6.0, 1.0, "suffix:dB") var rise_rumble_db: float = -4.0
## Least distance between the start points of two hunted (S-010, T-100).
@export_range(0.0, 200.0, 1.0, "suffix:m") var spawn_spacing: float = 40.0

@export_group("Objectives (S-018)")
## Objectives of a game, at least one fuse (Q13).
@export_range(1, 4) var objectives_per_game: int = 3
## Seconds a download runs on its terminal (Q13).
@export_range(1.0, 300.0, 1.0, "suffix:s") var download_time: float = 45.0
## The hard disk scratching while it downloads, in meters, and how often.
@export_range(0.0, 30.0, 0.5, "suffix:m") var disk_noise_range: float = 5.0
@export_range(0.5, 20.0, 0.5, "suffix:s") var disk_noise_interval: float = 3.0
## A hunted reads a post-it from this close, in meters, the crosshair within
## code_read_angle of it: the HUD then writes what it says (T-271).
@export_range(0.5, 10.0, 0.1, "suffix:m") var code_read_reach: float = 2.5
@export_range(5.0, 90.0, 1.0, "suffix:°") var code_read_angle: float = 25.0
## The wrong code's beep on the transformer's keypad, in meters.
@export_range(0.0, 20.0, 0.5, "suffix:m") var beep_range: float = 3.0
## Both relay switches must be thrown within this many seconds (Q13). 25 s
## (15 s in the spec, T-268): the two switches of a pair are up to 90 m apart
## by the paths, 17 s at a sprint, 30 s at a walk; alone, one must run.
@export_range(1.0, 120.0, 1.0, "suffix:s") var relay_window: float = 25.0
## The noise of a relay switch, in meters.
@export_range(0.0, 30.0, 0.5, "suffix:m") var relay_range: float = 6.0
## The two relay switches drawn are at most this far apart, in meters.
@export_range(10.0, 300.0, 5.0, "suffix:m") var relay_max_distance: float = 70.0
