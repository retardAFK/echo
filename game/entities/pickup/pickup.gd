class_name Pickup
extends Node3D
## Something lying in the cité that the hunted can take (spec S-008): a bottle
## to throw (Q1) or an alarm clock to place (Q3). Aim at it and press
## "interact": it goes into the inventory at once, without a sound, if there is
## room, and disappears.

signal taken

@export var settings: RuseSettings
@export var kind := Inventory.Kind.BOTTLE


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	DrawRange.limit(self, DrawRange.SMALL)


func get_prompt() -> String:
	return (
		"HUD_INTERACT_PICKUP_BOTTLE"
		if kind == Inventory.Kind.BOTTLE
		else "HUD_INTERACT_PICKUP_DECOY"
	)


## Whether a hunted standing at this position is close enough to take it.
func can_interact(from: Vector3) -> bool:
	if is_queued_for_deletion():
		return false
	var gap := from - global_position
	return (
		Vector2(gap.x, gap.z).length() <= settings.pickup_reach
		and absf(gap.y) <= settings.pickup_reach
	)


## Whether this user has room for it (anything with an `inventory`).
func wanted_by(user: Node) -> bool:
	var inventory: Inventory = user.get("inventory")
	return inventory != null and inventory.can_take(kind)


func interact(user: Node) -> void:
	if not can_interact(user.global_position) or not wanted_by(user):
		return
	var inventory: Inventory = user.get("inventory")
	if inventory.take(kind):
		taken.emit()
		queue_free()
