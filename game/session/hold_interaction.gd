class_name HoldInteraction
extends RefCounted
## Drives the thing a hunted (the player or the AI prey) holds "interact" on
## (spec S-007): it holds the current target while the key is down, and lets go
## of it when the key is released or the target changes (out of reach, aim
## turned away). A holdable target has hold(user, delta), release(user) and
## get_hold_ratio().

var target: Node
var holding := false


## One frame: the target in reach (or null), and whether "interact" is held.
func update(user: Node, new_target: Node, held: bool, delta: float) -> void:
	if not is_holdable(new_target):
		new_target = null
	if new_target != target:
		_let_go(user)
		target = new_target
	if target == null:
		return
	if held:
		holding = true
		target.hold(user, delta)
	else:
		_let_go(user)


## Progress of the current hold, from 0 to 1 (0 when nothing is held).
func get_ratio() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	return target.get_hold_ratio()


static func is_holdable(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("hold")


func _let_go(user: Node) -> void:
	if holding and target != null and is_instance_valid(target):
		target.release(user)
	holding = false
