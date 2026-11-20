class_name RouteSettings
extends Resource
## Tunable values of the routes replayed on the map at the end of a game
## (spec S-020, T-339, piste U2). Starting points: they only record and show,
## they change no rule of the game.

## Time between two recorded positions of each player, in seconds.
@export_range(0.25, 10.0, 0.25, "suffix:s") var sample_time: float = 2.0
## Positions kept per player. Once reached, every other position is dropped and
## the time between two doubles, so a long game stays small to send online.
@export_range(50, 5000, 10) var max_points: int = 600
## Beyond this speed between two positions, the player was moved (to the prison,
## out of a cage): the line is broken there, in meters per second. The fastest
## run is the second wind's 6.5 m/s (T-338).
@export_range(1.0, 50.0, 0.5, "suffix:m/s") var break_speed: float = 9.0
## The whole game is replayed in this many seconds on the end screen.
@export_range(2.0, 60.0, 0.5, "suffix:s") var replay_time: float = 12.0
## The finished replay stays on screen this long before it starts again.
@export_range(0.0, 20.0, 0.5, "suffix:s") var replay_hold: float = 3.0
