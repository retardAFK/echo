class_name TipSettings
extends Resource
## Tunable values of the first-time tips (spec S-020, T-329, piste U1): a
## bubble the first time the hunted sees a hiding spot, a terminal or a fuse
## box. Starting points.

## Seen: closer than this, in view and not behind a wall, in meters.
@export_range(1.0, 30.0, 0.5, "suffix:m") var see_range: float = 8.0
## Seconds a bubble stays on screen.
@export_range(1.0, 30.0, 0.5, "suffix:s") var show_time: float = 7.0
## Seconds between two looks around (seeing is a few rays, not every frame).
@export_range(0.05, 2.0, 0.05, "suffix:s") var check_interval: float = 0.25
