class_name PingSettings
extends Resource
## Tunable values of the team pings (spec S-020, T-328, piste A1): a key to
## mark "monstre ici" or "ici" for the teammates. Starting points.

## Farthest point a hunted can mark, in meters.
@export_range(5.0, 200.0, 1.0, "suffix:m") var reach: float = 60.0
## The aim passing this close to the monster, seen, marks the monster, in meters.
@export_range(0.2, 5.0, 0.1, "suffix:m") var monster_radius: float = 1.5
## Seconds a mark stays on the teammates' screens.
@export_range(1.0, 60.0, 0.5, "suffix:s") var time: float = 8.0
## Seconds between two marks of one hunted (no spam).
@export_range(0.0, 30.0, 0.5, "suffix:s") var cooldown: float = 2.0
## An AI hunted this close to a "monstre ici" mark runs from the monster, in
## meters (as if it heard it).
@export_range(0.0, 100.0, 1.0, "suffix:m") var ai_flee_range: float = 25.0
