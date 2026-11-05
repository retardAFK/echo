class_name VisualSettings
extends Resource
## Tunable values for the night look (spec S-005, ambiance A).
## Shaders and scenes read these values; none are written in the code.

@export_group("Night")
## Color of the sky and of the fog, the same so the fog swallows the far end.
@export var fog_color := Color(0.10, 0.11, 0.13)
## Depth fog density. 0.035 lets the player see about 25 m.
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.035
## Color of the faint ambient light, a cold blue.
@export var ambient_color := Color(0.5, 0.55, 0.7)
## Energy of the ambient light.
@export_range(0.0, 2.0, 0.01) var ambient_energy: float = 0.2
## Color of the moonlight.
@export var moon_color := Color(0.55, 0.62, 0.85)
## Energy of the moonlight, very faint.
@export_range(0.0, 2.0, 0.01) var moon_energy: float = 0.08
