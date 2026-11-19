class_name Deafness
extends RefCounted
## The monster deafened by a firecracker that went off at its feet (S-020,
## T-312, piste R1): for a few seconds it hears nothing, not even through its
## scan, and its screen shows no noise. The AI monster and the played one both
## hold one; online, the room sends the played one how long it has left.

## Seconds it still hears nothing.
var left := 0.0


## Deafens it for duration seconds, never shortening a longer deafness.
func deafen(duration: float) -> void:
	left = maxf(left, duration)


## Counts one frame down.
func update(delta: float) -> void:
	left = maxf(left - delta, 0.0)


func is_deaf() -> bool:
	return left > 0.0


## Whether node, an AI or played monster, is deaf now.
static func of(node: Object) -> bool:
	if node == null or not "deafness" in node:
		return false
	var deafness: Variant = node.get("deafness")
	return deafness is Deafness and (deafness as Deafness).is_deaf()
