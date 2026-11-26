class_name VersusWeapon
extends Resource
## How a Versus gun shoots (spec S-025, Q2, T-403): one .tres per gun in
## data/weapons/, referenced by its VersusItem (weapon). HunterKit.fire
## shoots it: rays that hit at once (HitscanShot), one per pellet, spread
## at random within spread degrees, each with its tracer (Tracer) and its
## damage number on the boss. To add a gun: docs/MODULES.md, "Le mode
## Versus".

## Held fire keeps shooting (a machine gun), else one shot per click.
@export var automatic := true
## Seconds between two shots (0.1: ten a second).
@export_range(0.02, 3.0, 0.01, "suffix:s") var fire_interval: float = 0.1
## Damage of a pellet on the body; in the face, times face_multiplier.
@export_range(0.0, 500.0, 0.5) var damage: float = 6.0
@export_range(1.0, 5.0, 0.1) var face_multiplier: float = 2.0
## Poise a pellet adds on the body, and in the face (the boss kneels when
## its poise is full).
@export_range(0.0, 100.0, 0.1) var poise: float = 0.5
@export_range(0.0, 100.0, 0.1) var face_poise: float = 3.0
## Rays per shot (a shotgun has several), and how far they stray from the
## crosshair, in degrees.
@export_range(1, 20) var pellets: int = 1
@export_range(0.0, 20.0, 0.1, "suffix:°") var spread: float = 2.0
## Shots in a clip, and seconds to reload it from the spare ammo.
@export_range(1, 200) var clip: int = 30
@export_range(0.1, 10.0, 0.1, "suffix:s") var reload_time: float = 1.5
## Farthest a ray hits, in meters.
@export_range(1.0, 300.0, 1.0, "suffix:m") var reach: float = 120.0
## Range of a shot's noise, in meters.
@export_range(0.0, 60.0, 0.5, "suffix:m") var noise_range: float = 20.0
## Color of its tracers.
@export var tracer_color := Color(0.4, 1.0, 0.95)
## How much a shot shakes the camera (0 to 1).
@export_range(0.0, 1.0, 0.05) var shake: float = 0.15
