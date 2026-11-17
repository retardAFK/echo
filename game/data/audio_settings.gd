class_name AudioSettings
extends Resource
## Tunable values for how the game sounds (spec S-012).

@export_group("Space (T-142)")
## Volume of a sound at the edge of its perceived range, in decibels: it
## goes linearly from 0 dB at its source to this value.
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var edge_db: float = -20.0
## Volume lost for each wall between a sound and the listener, in decibels.
@export_range(-30.0, 0.0, 1.0, "suffix:dB") var wall_db: float = -8.0
## Volume lost by a sound right behind the listener, in decibels.
@export_range(-12.0, 0.0, 0.5, "suffix:dB") var behind_db: float = -3.0
## Range of a game sound whose player has no max_distance, in meters.
@export_range(1.0, 100.0, 1.0, "suffix:m") var default_range: float = 20.0
## A wall closer than this to a sound is the thing that makes it (a door, a
## shutter, a box in a wall): it does not muffle it, in meters.
@export_range(0.0, 2.0, 0.05, "suffix:m") var own_wall_margin: float = 0.5
## Time between two updates of a long sound's volume, in seconds.
@export_range(0.05, 1.0, 0.05, "suffix:s") var track_interval: float = 0.15

@export_group("Own sounds (T-143)")
## Volume of one's own walking footstep (4 m), in decibels.
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_walk_db: float = -20.0
## Volume added each time a footstep's range doubles, in decibels: a run or a
## puddle sounds louder than a walk, a crouched step quieter.
@export_range(0.0, 20.0, 0.5, "suffix:dB") var self_db_per_doubling: float = 8.0
## Quietest and loudest of one's own sounds, in decibels.
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_min_db: float = -32.0
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_max_db: float = -8.0
