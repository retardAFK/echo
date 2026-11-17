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
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_walk_db: float = -26.0
## Volume added each time a footstep's range doubles, in decibels: a run or a
## puddle sounds louder than a walk, a crouched step quieter.
@export_range(0.0, 20.0, 0.5, "suffix:dB") var self_db_per_doubling: float = 8.0
## Quietest and loudest of one's own sounds, in decibels.
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_min_db: float = -32.0
@export_range(-60.0, 0.0, 1.0, "suffix:dB") var self_max_db: float = -14.0

@export_group("Wind (T-144)")
## Seconds between the ends of two gusts, at random between these.
@export var gust_interval := Vector2(25.0, 50.0)
## Seconds a gust blows at full strength, at random between these.
@export var gust_length := Vector2(6.0, 10.0)
## Seconds the wind takes to rise before a gust, and to fall after.
@export_range(0.1, 10.0, 0.1, "suffix:s") var gust_rise: float = 2.0
## Volume the wind gains at the height of a gust, in decibels.
@export_range(0.0, 24.0, 0.5, "suffix:dB") var gust_db: float = 9.0
## Volume the wind loses indoors, in decibels.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var indoor_wind_db: float = -12.0
## Volume of the gust's whistle at its height, in decibels.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var whistle_db: float = -10.0

@export_group("Monster voice (T-145)")
## Volume of the scan's drone once the monster listens, in decibels.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var drone_db: float = -14.0
## Volume of the drone as the concentration begins, in decibels.
@export_range(-60.0, 0.0, 0.5, "suffix:dB") var drone_min_db: float = -30.0
## How much higher the drone sounds once the monster listens (0.15 = 15 %).
@export_range(0.0, 1.0, 0.01) var drone_pitch_rise: float = 0.15
## Volume of the crackle of a scanned building's lights, in decibels.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var crackle_db: float = -4.0
## Distance the crackle of the lights carries, in meters.
@export_range(1.0, 60.0, 0.5, "suffix:m") var crackle_range: float = 18.0

@export_group("Music (T-146)")
## Distance to the monster under which the pulse joins in, in meters.
@export_range(1.0, 100.0, 1.0, "suffix:m") var unease_range: float = 35.0
## Distance to the monster under which the shrill strings join in, in meters.
@export_range(1.0, 100.0, 1.0, "suffix:m") var dread_range: float = 15.0
## Seconds a level is kept at least before the next change.
@export_range(0.0, 20.0, 0.5, "suffix:s") var level_hold: float = 3.0
## Seconds a layer takes to come in.
@export_range(0.1, 30.0, 0.5, "suffix:s") var layer_rise: float = 4.0
## Seconds a layer takes to go away.
@export_range(0.1, 60.0, 0.5, "suffix:s") var layer_fall: float = 10.0
## Monster role: a noise heard this close brings the pulse in, in meters.
@export_range(1.0, 100.0, 1.0, "suffix:m") var monster_heard_range: float = 25.0
## Monster role: seconds the pulse stays after the last such noise.
@export_range(0.5, 30.0, 0.5, "suffix:s") var monster_heard_memory: float = 5.0
## Volume of each layer at full, in decibels: background, pulse, strings.
@export var layer_db := Vector3(-10.0, -10.0, -10.0)

@export_group("Mix (T-147)")
## Level of the loudest noises, in decibels, so that everything at once stays
## under -3 dBFS in the browser (measured with the mixing bench).
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var car_alarm_db: float = -6.0
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var scream_db: float = -5.0


## Level of a noise type the ears play, in decibels.
func level_db(type: NoiseEvent.Type) -> float:
	match type:
		NoiseEvent.Type.CAR_ALARM:
			return car_alarm_db
		NoiseEvent.Type.SCREAM:
			return scream_db
	return 0.0
