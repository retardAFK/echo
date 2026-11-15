class_name MonsterBodySettings
extends Resource
## Tunable values of the hunter's animated body (spec S-011, T-123).

@export_group("Choice")
## Below this horizontal speed it stands still (idle), in m/s.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var still_speed: float = 0.3
## From this speed it walks rather than prowls, in m/s.
@export_range(0.5, 6.0, 0.1, "suffix:m/s") var walk_from: float = 2.5
## From this speed it runs, in m/s.
@export_range(1.0, 10.0, 0.1, "suffix:m/s") var run_from: float = 4.75
## Blend between two animations, in seconds.
@export_range(0.0, 1.0, 0.01, "suffix:s") var blend_time: float = 0.25

@export_group("Playback")
## Speed each moving animation was made for, in m/s.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var prowl_speed: float = 1.5
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var walk_speed: float = 3.5
@export_range(0.1, 12.0, 0.1, "suffix:m/s") var run_speed: float = 6.0
## Bounds of the playback speed.
@export_range(0.1, 1.0, 0.05) var min_scale: float = 0.6
@export_range(1.0, 3.0, 0.05) var max_scale: float = 1.6

@export_group("Gestures")
## Length of the one-shot gestures, as made by tools/blender/hunter.py (T-127).
@export_range(0.1, 3.0, 0.05, "suffix:s") var catch_time: float = 0.9
@export_range(0.1, 3.0, 0.05, "suffix:s") var crush_time: float = 0.8
