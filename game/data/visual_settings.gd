class_name VisualSettings
extends Resource
## Tunable values for the night look (spec S-005, ambiance A).
## Shaders and scenes read these values; none are written in the code.

@export_group("Night")
## Color of the sky and of the fog, the same so the fog swallows the far end.
@export var fog_color := Color(0.10, 0.11, 0.13)
## Depth fog density. 0.035 lets the player see about 25 m.
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.035
## Depth fog density in the monster's role (S-020, T-306, piste E4): it sees
## normally (D-008) but the night hides the hunted beyond about 12 m.
@export_range(0.0, 0.3, 0.001) var monster_fog_density: float = 0.073
## Farthest distance the cameras draw, in meters (S-006): the fog has already
## swallowed everything beyond, so nothing farther costs a draw call.
@export_range(10.0, 500.0, 1.0, "suffix:m") var view_distance: float = 90.0
## Nearest distance the cameras draw. Larger than Godot's 0.05 m so the depth
## buffer stays precise far away: coplanar faces stop flickering (D-011).
@export_range(0.01, 0.3, 0.01, "suffix:m") var near_clip: float = 0.1
## Color of the faint ambient light, a cold blue.
@export var ambient_color := Color(0.5, 0.55, 0.7)
## Energy of the ambient light.
@export_range(0.0, 2.0, 0.01) var ambient_energy: float = 0.2
## Color of the moonlight.
@export var moon_color := Color(0.55, 0.62, 0.85)
## Energy of the moonlight, very faint.
@export_range(0.0, 2.0, 0.01) var moon_energy: float = 0.08

@export_group("Indoor fog (S-014)")
## Fog of the hospital's corridors: the depth fog thickens to this density
## while the camera is in an IndoorFog zone, so the neons fade into it.
@export_range(0.0, 0.3, 0.001) var indoor_fog_density: float = 0.09
## Color of that fog, a dirty sea green under the neons.
@export var indoor_fog_color := Color(0.13, 0.17, 0.15)
## Time for the fog to thicken or thin out when the camera crosses a zone.
@export_range(0.1, 5.0, 0.1, "suffix:s") var indoor_fog_time: float = 1.5

@export_group("Screen filter")
## Color levels per channel, fewer means a more retro image.
@export_range(2, 256) var color_levels: int = 24
## Strength of the ordered 4 x 4 dithering in the gradients.
@export_range(0.0, 2.0, 0.05) var dither_strength: float = 0.6
## Strength of the film grain.
@export_range(0.0, 0.5, 0.005) var grain_strength: float = 0.03
## How many times per second the grain changes.
@export_range(1.0, 60.0, 1.0, "suffix:/s") var grain_rate: float = 12.0

@export_group("Wobble")
## Screen grid the vertices snap to, half the internal resolution.
## (0, 0) turns the wobble off, for players who feel sick.
@export var vertex_snap := Vector2(320, 180)

@export_group("Scan")
## How much darker everything outside the scanned building gets (0.7 = 70 %).
@export_range(0.0, 1.0, 0.05) var scan_dim: float = 0.7
## How much color everything outside the scanned building loses.
@export_range(0.0, 1.0, 0.05) var scan_desaturation: float = 0.8
## Pale color of the building's edges and of the wave. Never orange.
@export var scan_edge_color := Color(0.8, 0.84, 0.88)
## Width of the glowing edges of the building, in meters.
@export_range(0.05, 1.0, 0.05, "suffix:m") var scan_edge_width: float = 0.15
## Time between two waves leaving the building.
@export_range(0.2, 5.0, 0.1, "suffix:s") var scan_wave_interval: float = 1.0
## Distance a wave travels from the building before it fades out.
@export_range(1.0, 50.0, 0.5, "suffix:m") var scan_wave_reach: float = 12.0
## Thickness of the wave, in meters.
@export_range(0.1, 3.0, 0.05, "suffix:m") var scan_wave_width: float = 0.4
## Time for the scan look to fade in or out.
@export_range(0.0, 2.0, 0.05, "suffix:s") var scan_fade_time: float = 0.3
