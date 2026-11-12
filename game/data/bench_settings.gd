class_name BenchSettings
extends Resource
## Values of the bench mode (spec S-009, Q2, T-075).

## Length of the camera tour, in seconds, warm-up excluded.
@export_range(10.0, 600.0, 1.0, "suffix:s") var duration: float = 60.0
## First seconds not counted (shader compilation, streaming).
@export_range(0.0, 30.0, 0.5, "suffix:s") var warm_up: float = 3.0
## How far the camera turns around each viewpoint, in degrees, each way.
@export_range(0.0, 180.0, 1.0, "suffix:°") var sweep_angle: float = 35.0
## Seed of the game played by the two AIs, the same at every run.
@export var game_seed: int = 9
