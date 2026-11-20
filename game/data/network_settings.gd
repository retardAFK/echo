class_name NetworkSettings
extends Resource
## Tunable values of the network of the cité (spec S-018, part B, Q9 to Q12):
## terminals, cameras, loudspeakers and metal shutters. Proposals of the
## spec, to tune in playtest.

@export_group("Terminals")
## Holding "interact" on a terminal to sit at it, in seconds (Q10).
@export_range(0.1, 10.0, 0.1, "suffix:s") var sit_time: float = 1.0
## How far from a terminal's front a hunted uses it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var reach: float = 1.4
## The keyboard of a hunted at a terminal, in meters (Q10).
@export_range(0.0, 20.0, 0.5, "suffix:m") var keyboard_range: float = 3.0
## Time between two keyboard noises, in seconds.
@export_range(0.2, 10.0, 0.1, "suffix:s") var keyboard_interval: float = 2.0
## The monster switches a terminal off for this long, in seconds (Q12).
@export_range(1.0, 600.0, 1.0, "suffix:s") var off_time: float = 60.0
## Holding "interact" to switch a terminal off or smash a camera, in seconds.
@export_range(0.1, 10.0, 0.1, "suffix:s") var monster_hold: float = 1.0
## A lit screen's light, in meters (it shows the one at the keyboard).
@export_range(0.5, 10.0, 0.5, "suffix:m") var screen_light_range: float = 3.0
## A screen lit by the one at the keyboard shows only this close to the
## viewer's camera, in meters; further, it looks idle and casts no light
## (S-020, T-323, piste N4: going to a terminal was nearly suicidal).
@export_range(1.0, 100.0, 0.5, "suffix:m") var lit_screen_range: float = 10.0

@export_group("Cameras")
## The monster smashing a camera, in meters (Q11).
@export_range(0.0, 50.0, 0.5, "suffix:m") var smash_range: float = 10.0
## How far below or beside a camera the monster reaches it, in meters.
@export_range(0.5, 5.0, 0.1, "suffix:m") var camera_reach: float = 2.0
## How far a camera sees the hunted and the monster, in meters.
@export_range(5.0, 100.0, 1.0, "suffix:m") var camera_sight: float = 40.0
## A camera's field of view, in degrees.
@export_range(30.0, 120.0, 1.0, "suffix:°") var camera_fov: float = 70.0
## Cameras sweep left and right (S-020, T-336, piste N3): this far each side
## of where they were set, in degrees, back and forth in camera_sweep_period
## seconds. 0 keeps them still.
@export_range(0.0, 90.0, 1.0, "suffix:°") var camera_sweep_angle: float = 35.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var camera_sweep_period: float = 8.0

@export_group("Loudspeakers")
## A loudspeaker's noise, in meters (Q11).
@export_range(0.0, 60.0, 0.5, "suffix:m") var speaker_range: float = 25.0
## How long it sounds, and the time between two of its noises, in seconds.
@export_range(0.5, 30.0, 0.5, "suffix:s") var speaker_time: float = 5.0
@export_range(0.2, 5.0, 0.1, "suffix:s") var speaker_interval: float = 1.0

@export_group("Shutters")
## How long a shutter stays down, in seconds (Q11).
@export_range(1.0, 120.0, 1.0, "suffix:s") var shutter_time: float = 20.0
## Its noise going down and up, in meters (Q11).
@export_range(0.0, 50.0, 0.5, "suffix:m") var shutter_range: float = 12.0
## Seconds before it can go down again, counted from when it went down.
@export_range(1.0, 600.0, 1.0, "suffix:s") var shutter_recharge: float = 60.0
