class_name ChaseSettings
extends Resource
## Tunable values of the chase statistics shown at the end of a game (spec
## S-020, T-322, piste E8). Starting points: they only count, they change no
## rule of the game.

## A chase starts when the monster sees a free hunted this close, in meters
## (the monster's view at night is 12 m since T-306).
@export_range(1.0, 50.0, 0.5, "suffix:m") var start_range: float = 12.0
## Half angle of the monster's view for a chase to start or go on, in degrees.
@export_range(10.0, 180.0, 1.0, "suffix:°") var view_half_angle: float = 60.0
## Beyond this distance the monster counts as not seeing the hunted, in meters.
@export_range(1.0, 100.0, 0.5, "suffix:m") var lost_range: float = 25.0
## A chase is a successful escape once the monster has not seen the hunted for
## this long (hidden, out of sight or too far), in seconds. The AI monster
## turns a chase into a search after 3 s without sight, then searches 8 s
## (MonsterSettings.lose_sight_time and search_time).
@export_range(1.0, 60.0, 0.5, "suffix:s") var escape_time: float = 10.0
## Time between two looks of the statistics, in seconds (a ray per hunted).
@export_range(0.02, 1.0, 0.01, "suffix:s") var sample_time: float = 0.1
