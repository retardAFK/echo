class_name ExitZone
extends Area3D
## The far end of the exit tunnel (spec S-007, Q4): the hunted who gets there
## is out, and wins.

## Emitted when a body enters the zone.
signal reached(body: Node3D)

## Physics layer of the hunted and the AI prey.
const ACTORS_LAYER := 1 << 2


func _ready() -> void:
	collision_layer = 0
	collision_mask = ACTORS_LAYER
	body_entered.connect(reached.emit)
