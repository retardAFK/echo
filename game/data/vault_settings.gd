class_name VaultSettings
extends Resource
## Tunable values of the windows and low walls to climb over (spec S-020,
## T-340, piste E6). Starting points from Maxime's notebook (0.5 s for the
## hunted, 1.5 s for the monster); the rest is proposed in the plan
## (specs/S-020-retours-de-test/plan-T-340-enjambements.md).

## Time the hunted takes to get over, in seconds.
@export_range(0.1, 5.0, 0.05, "suffix:s") var hunted_time: float = 0.5
## Time the monster (AI or played) takes to get over, in seconds.
@export_range(0.1, 5.0, 0.05, "suffix:s") var monster_time: float = 1.5
## Noise of the hunted getting over, in meters.
@export_range(0.0, 50.0, 0.5, "suffix:m") var hunted_range: float = 5.0
## Noise of the monster getting over, in meters.
@export_range(0.0, 50.0, 0.5, "suffix:m") var monster_range: float = 8.0
## How close to the passage one must stand to get over it, in meters.
@export_range(0.3, 5.0, 0.1, "suffix:m") var reach: float = 1.5
## How far past the wall the body lands, in meters (from the wall's face).
@export_range(0.2, 3.0, 0.05, "suffix:m") var landing_distance: float = 0.7
## How much higher than the top of the wall the body rises, in meters.
@export_range(0.0, 1.0, 0.05, "suffix:m") var clearance: float = 0.2
## Extra path cost of a passage for the AI monster, in meters: an AI takes
## it when the way around is longer than this. 1.5 s at its run speed (6 m/s).
@export_range(0.0, 100.0, 0.5, "suffix:m") var monster_link_cost: float = 9.0
## Extra path cost of a passage for the AI hunted, in meters: 0.5 s at its
## run speed (5 m/s).
@export_range(0.0, 100.0, 0.5, "suffix:m") var hunted_link_cost: float = 2.5
