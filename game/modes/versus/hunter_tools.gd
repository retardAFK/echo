class_name HunterTools
extends RefCounted
## What a Versus hunted's tools do (spec S-024, Q13, T-377), used with the
## keys gadget_1 and gadget_2 by HunterKit.use_tool(): the flash grenade
## stuns the boss (S-025), the medkit gives back a point,
## the firecracker and the smoke are the Traque's gadgets (S-020, S-023),
## put down by the player. Each returns true if the tool was used (one use
## spent).


static func use(kit: HunterKit, item: VersusItem) -> bool:
	match item.id:
		&"flash_grenade":
			return flash(kit)
		&"medkit":
			return medkit(kit)
	if item.gadget_kind >= 0:
		return gadget(kit, item.gadget_kind)
	return false


## The flash grenade (S-025, Q2): thrown along the aim, it goes off up to
## flash_throw away (or against what it meets first, the boss too) in a
## white burst; the boss within flash_radius of it, in its line, is stunned
## flash_stun.
static func flash(kit: HunterKit) -> bool:
	var settings := kit.mode.settings
	var from := kit.eye()
	var to := from + kit.aim() * settings.flash_throw
	var space := kit.body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, Flare.LAYERS)
	query.exclude = [kit.body.get_rid()]
	var hit := space.intersect_ray(query)  # It goes off on the boss too.
	var point: Vector3 = to if hit.is_empty() else hit.position - kit.aim() * 0.3
	kit.mode.show_flash(point)
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, point, settings.flash_noise_range, kit.body)
	var boss := kit.mode.boss
	if boss == null:
		return true
	var target := boss.body.global_position + Vector3.UP * 1.2
	if target.distance_to(point) > settings.flash_radius:
		return true
	var line := PhysicsRayQueryParameters3D.create(point, target, 1 | 2)
	line.exclude = [boss.body.get_rid()]
	if space.intersect_ray(line).is_empty():
		boss.stun(settings.flash_stun)
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
