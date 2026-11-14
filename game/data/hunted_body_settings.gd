class_name HuntedBodySettings
extends Resource
## Tunable values of the hunted's animated bodies (spec S-011, T-126).

@export_group("Choice")
## Below this horizontal speed a hunted stands still (idle), in m/s.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var still_speed: float = 0.3
## Blend between two animations, in seconds.
@export_range(0.0, 1.0, 0.01, "suffix:s") var blend_time: float = 0.2

@export_group("Playback")
## Speed each moving animation was made for (its feet do not slide), in m/s.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var walk_speed: float = 2.2
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var run_speed: float = 4.0
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var crouch_speed: float = 1.2
## Bounds of the playback speed, so a slow or fast body still looks right.
@export_range(0.1, 1.0, 0.05) var min_scale: float = 0.6
@export_range(1.0, 3.0, 0.05) var max_scale: float = 1.6
