class_name GadgetUse
extends RefCounted
## How a hunted Player puts things in the world (spec S-023, T-351): a gadget
## of the list (GadgetList) through its deploy(user) contract, and anything
## set on the ground in front of it (alarm clocks, and the gadgets that are
## placed). Kept apart from player.gd so the player keeps one way to use every
## gadget, whatever the list holds.

## How far down a placed thing looks for the ground in front of the player, in meters.
const GROUND_SEARCH := 2.5


## Uses the gadget that counts as kind in user's inventory: its GadgetDef
## scene puts itself in the world (deploy), and user announces the ruse it
## counts as (Player.ruse_used). Returns the gadget placed, or null (none
## left, hidden, or no such gadget in the list).
static func use(user: Player, kind: Inventory.Kind) -> Node3D:
	var gadget_def := GadgetList.default().by_kind(kind)
	if gadget_def == null or user.hiding_in != null or not user.inventory.use(kind):
		return null
	var gadget: Node3D = gadget_def.scene.instantiate()
	var ruse: StringName = gadget.deploy(user)
	if ruse != &"":
		user.ruse_used.emit(ruse)
	return gadget


## Uses the gadget of a slot of user's Loadout (keys gadget_1, gadget_2,
## S-023, T-353). Returns the gadget placed, or null.
static func use_slot(user: Player, slot: int) -> Node3D:
	var kind := Loadout.kind_in(user.loadout, slot)
	return use(user, kind as Inventory.Kind) if kind >= 0 else null


## Puts placed on the ground in front of user, or at its feet when a wall is
## in front or there is no ground there; the gesture makes a faint noise.
static func place_on_ground(user: Player, placed: Node3D) -> void:
	var settings := user.ruse_settings
	var offset := -user.global_basis.z * settings.decoy_place_distance
	var spot := user.global_position
	if not user.test_move(user.global_transform, offset):  # A wall in front: at the feet.
		var ahead := user.global_position + offset
		var query := PhysicsRayQueryParameters3D.create(
			ahead + Vector3.UP, ahead + Vector3.DOWN * GROUND_SEARCH, user.collision_mask
		)
		query.exclude = [user.get_rid()]
		var hit := user.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			spot = hit.position
	user.get_parent().add_child(placed)
	placed.global_position = spot
	NoiseBus.emit_noise(NoiseEvent.Type.THROW, user.global_position, settings.gesture_range, user)
	user.gesture.play(HuntedBody.Gesture.PICK, Player.BODY_SETTINGS.pick_time)
