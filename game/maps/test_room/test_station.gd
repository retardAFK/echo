class_name TestStation
extends Resource
## One station of the test room (spec S-023, Q8 and Q9, T-356): a thing of the
## game set down in the room with a sign naming it. Adding a station is one
## line in game/maps/test_room/stations.tres (TestStationList); the scene is
## the game's own, so it behaves as in a real game.

## Key of the sign's text in strings.csv.
@export var name_key := ""
## The thing: any scene of game/entities/ that works on its own.
@export var scene: PackedScene
## Where it stands in the room, and which way it faces (degrees).
@export var position := Vector3.ZERO
@export var yaw_degrees := 0.0
## Values of its exported properties, set before it enters the room, such
## as {"top": 0.6} for a low wall to climb.
@export var properties := {}
