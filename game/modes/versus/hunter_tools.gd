class_name HunterTools
extends RefCounted
## What a Versus hunted's tools do (spec S-024, Q13, T-377), used with the
## keys gadget_1 and gadget_2 by HunterKit.use_tool(): the sonic cannon
## pushes the boss back and breaks its blow, the medkit gives back a point,
## the firecracker and the smoke are the Traque's gadgets (S-020, S-023),
## put down by the player. Each returns true if the tool was used (one use
## spent).


static func use(kit: HunterKit, item: VersusItem) -> bool:
	match item.id:
		&"sonic_cannon":
			return sonic(kit)
		&"medkit":
			return medkit(kit)
	if item.gadget_kind >= 0:
		return gadget(kit, item.gadget_kind)
	return false


## The sonic cannon (Q13): a blast in a cone; the boss in it, in sight, is
## pushed back sonic_push, its blow broken, its poise filled. Heard far.
static func sonic(kit: HunterKit) -> bool:
	var settings := kit.mode.settings
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, kit.eye(), settings.sonic_noise_range, kit.body)
	if kit.view_model != null:
		kit.view_model.kick(2.0)
	var boss := kit.mode.boss
	if boss == null:
		return true
	var target := boss.body.global_position + Vector3.UP * 1.2
	var offset := target - kit.eye()
	if offset.length() > settings.sonic_range:
		return true
	if rad_to_deg(offset.angle_to(kit.aim())) > settings.sonic_half_angle:
		return true
	var query := PhysicsRayQueryParameters3D.create(kit.eye(), target, 1 | 2)
	query.exclude = [kit.body.get_rid(), boss.body.get_rid()]
	if not kit.body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return true
	boss.blasted(offset, settings.sonic_push, settings.sonic_poise)
	kit.mode.on_boss_hit(boss, kit.body, false, 0.0)
	return true


## The medkit (Q13): one point back to its hunted (reviving faster comes
## with T-378). Not spent at full health.
static func medkit(kit: HunterKit) -> bool:
	if not kit.vitals.heal(kit.mode.settings.medkit_heal):
		return false
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP,
		kit.body.global_position,
		kit.mode.settings.medkit_noise_range,
		kit.body
	)
	return true


## A gadget of the Traque (firecracker, smoke): the player puts it down as
## in the Traque, with one charge given just for that.
static func gadget(kit: HunterKit, kind: int) -> bool:
	var player := kit.body as Player
	if player == null:
		return false
	var inventory := player.inventory
	inventory.set_count(kind, inventory.count(kind) + 1)
	if GadgetUse.use(player, kind as Inventory.Kind) != null:
		return true
	inventory.set_count(kind, maxi(inventory.count(kind) - 1, 0))
	return false
