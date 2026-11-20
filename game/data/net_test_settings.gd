class_name NetTestSettings
extends Resource
## Thresholds of the online CI tests (spec S-020, T-330, piste T7): how much
## the client's prediction may stray from the room's position over a bad
## connection before the test fails. Starting points, from the measures of
## T-319 and T-321 (spec S-020, "Décision T-342").
## Read by tools/godot/net_walk.gd and tools/godot/net_match.gd.

@export_group("Walk (net_walk)")
## Delay added to every message, in ms.
@export_range(0, 500, 1, "suffix:ms") var walk_latency_ms: int = 150
## Largest gap allowed with the delay only, in meters.
@export_range(0.05, 5.0, 0.05, "suffix:m") var walk_max_gap: float = 0.5

@export_group("Bad connection (net_walk --bad-link)")
## Random extra delay up to this on what the client receives, in ms (bursts,
## as on a real WebSocket over a poor Wi-Fi).
@export_range(0, 500, 1, "suffix:ms") var bad_jitter_ms: int = 100
## Largest gap allowed over the bad connection, in meters: under the 1 m
## correction threshold (NetSettings), above which the player sees a snap.
## Measured 0.08 to 0.40 m on 5 local runs (T-330).
@export_range(0.05, 5.0, 0.05, "suffix:m") var bad_max_gap: float = 0.75

@export_group("Whole game (net_match)")
## Delay added to every message, in ms.
@export_range(0, 500, 1, "suffix:ms") var match_latency_ms: int = 75
## Largest gap allowed while a player walks, before it was ever caught (a
## capture moves it to a cage, which is no prediction error), in meters.
## Door jambs that hold a bot on the room give up to 2.2 m (T-347, CI and
## local runs of 20/11), hence the margin.
@export_range(0.05, 50.0, 0.05, "suffix:m") var match_max_gap: float = 4.0
