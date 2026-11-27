class_name HunterKit
extends Node
## A hunted's Versus kit (spec S-024, Q5, Q13 to Q15, Q29 to Q31, T-372,
## T-377): its health (HuntedVitals), stamina, what it carries
## (VersusLoadout: a weapon, two tools, spare ammo) and its dodge roll,
## plus, for the player, the first-person arms. A child of a Player or a
## Prey, added by VersusMode. It starts empty-handed (Q29) and gears up at
## the chests (VersusChest). The player's keys: left click fires (held: a
## machine gun keeps firing, the UV laser burns; S-025), right click held
## aims (T-412: the view zooms in, the shots stray less, it walks slower), R reloads, Space
## rolls, gadget_1 and gadget_2 use the tools (HunterTools), interact
## held revives a downed teammate (Q5, DownedHold), else opens a chest or
## takes from it. Downed, it crawls;
## out, it stays where it fell.
## An AI prey (T-383) goes where PreyFighter says (a downed teammate, a
## chest), rolls away from the boss's blows and fires bursts by itself at
## the boss when it sees it.

signal hurt(damage: int)

var mode: VersusMode
var body: CharacterBody3D
var vitals: HuntedVitals
var stamina: Stamina
var clip := 0
var loadout := VersusLoadout.new()
## The UV laser while it is the weapon, else null.
var laser: UvLaser
## The chest it holds interact on, and how long it has held it.
var chest: VersusChest
var chest_held := 0.0
## The keys of its player, held and pressed (T-381).
var keys := HeldKeys.new()
## A client's copy of its prompt (T-381), as the room says.
var mirror_prompt: Array = []
## Holding interact by a downed teammate to revive it (Q5).
var revive := DownedHold.new()
## Teammates it revived, for the end screen.
var revives_done := 0
## True while reloading.
var reloading := false
## True while its player aims, right click held with a gun (T-412).
var aiming := false
var view_model: ViewModel
## Where an AI prey goes (T-383).
var fighter: PreyFighter
var _cooldown := 0.0
var _reload_left := 0.0
var _dodge_left := 0.0
var _dodge_velocity := Vector3.ZERO
var _ai_wait := 0.0
var _ai_burst_left := 0.0
var _rng := RandomNumberGenerator.new()
## The AI's miss for the current burst (ai_aim_error).
var _aim_error := Basis.IDENTITY
var _ai_goal_wait := 0.0
var _sent_to: Variant = null
var _down_label: Label3D
var _fall := FallWatch.new()
## The player's own settings while it crawls (downed).
var _standing_settings: PlayerSettings
## The player's own settings while it aims (it walks slower).
var _hip_settings: PlayerSettings
var _crouched_by_fall := false


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "HunterKit"


func _ready() -> void:
	body = get_parent()
	vitals = HuntedVitals.new(mode.settings)
	stamina = Stamina.new(mode.settings)
	fighter = PreyFighter.new(mode.settings)
	vitals.downed.connect(_on_downed)
	vitals.revived.connect(_on_revived)
	vitals.out.connect(_on_out)
	revive.started.connect(_on_revive_started)
	if is_local():
		var camera: Camera3D = body.get_node("Head/Camera3D")
		view_model = ViewModel.new(ViewModel.Kind.HUNTER)
		camera.add_child(view_model)
		if "breath_hold" in body:
			var no_breath := PlayerSettings.new()
			no_breath.breath_hold_time = 0.0  # R reloads in Versus.
			body.breath_hold = BreathHold.new(no_breath)
	if body is Player:
		Loadout.equip((body as Player).inventory, [])  # Keys 1 and 2: the Versus tools.


## Takes item (from a chest, Q31); returns what it leaves in the chest.
func equip(item: VersusItem) -> VersusItem:
	var first := loadout.weapon == null
	var left := loadout.take(item)
	if item.slot != VersusItem.Slot.WEAPON:
		return left
	if item.weapon != null:
		clip = item.weapon.clip
		if first:
			loadout.spare_ammo += mode.settings.start_spare_ammo
	reloading = false
	_let_go_aim()  # Aims again next frame, with the new gun, if still held.
	if laser != null:
		laser.queue_free()
		laser = null
	if item.id == &"uv_laser":
		laser = UvLaser.new(self)
		add_child(laser)
	if view_model != null:
		view_model.set_weapon(item.id, _glow_of(item))
	return left


## The color of item's rarity on its gun (S-025), or the common glow.
func _glow_of(item: VersusItem) -> Color:
	var rarity := VersusRarity.of(item, mode.settings.rarities)
	if rarity == null or item.rarity <= 0:
		return ViewModel.SMG_GLOW
	return rarity.color


## A client (T-381): shows weapon in its hands, as the room says it took it.
func show_weapon(weapon: VersusItem) -> void:
	loadout.weapon = weapon
	_let_go_aim()
	if laser != null:
		laser.queue_free()
		laser = null
	if weapon != null and weapon.id == &"uv_laser":
		laser = UvLaser.new(self)
		add_child(laser)
	if view_model != null:
		view_model.set_weapon(weapon.id if weapon != null else &"", _glow_of(weapon))


## What holding interact does now (KitPrompts), or on a client what the room
## says.
func shown_prompt() -> Array:
	return mirror_prompt if mode.mirror else KitPrompts.of_hunter(self)


## Uses the tool of slot (0 or 1, keys gadget_1 and gadget_2); true if used.
func use_tool(slot: int) -> bool:
	var item := loadout.tool_in(slot)
	if item == null or not vitals.is_standing():
		return false
	if not HunterTools.use(self, item):
		return false
	loadout.spend(slot)
	return true


## Whether this machine's player drives it (its arms and HUD show here).
func is_local() -> bool:
	return body is Player and (body as Player).local_controls


## Whether a human plays it through its commands: on this machine, or on
## the room for a player online (T-381). Else an AI prey (or a client's
## mirror of its own player, which only shows what the room says).
func is_played() -> bool:
	return body is Player and not (body as Player).mirror_world


## Its eyes, where its shots leave from.
func eye() -> Vector3:
	return body.call(&"get_eye_position")


## Where it aims: where the crosshair points (S-025, T-402: the camera's
## ray, from behind the shoulder) for the player here or, from its commands'
## look, on the room; the boss for an AI.
func aim() -> Vector3:
	if is_local():
		var head: Node3D = body.get_node("Head")
		if mode.first_person():
			return -head.global_basis.z
		return VersusView.aim_direction(body, eye(), head.global_basis, mode.settings)
	if is_played():
		var commands := (body as Player).commands
		var look := Basis.from_euler(Vector3(commands.pitch, commands.yaw, 0.0))
		return VersusView.aim_direction(body, eye(), look, mode.settings)
	var boss := mode.boss
	if boss == null:
		return -body.global_basis.z
	var target := boss.body.global_position + Vector3.UP * 1.2
	return _aim_error * (target - eye()).normalized()


## Fires its gun once if it can (S-025, T-403): each pellet's ray hits at
## once (HitscanShot), the boss if it meets it, with a tracer from the
## muzzle; or, for the precision rifle, a straight Flare (T-404). Damage
## times its rarity's; a gun that pushes (the sonic shotgun) pushes the boss
## back for the share of pellets that hit it. True if it shot.
func fire() -> bool:
	var gun := loadout.gun()
	if gun == null:
		return false
	if not vitals.is_standing() or reloading or _cooldown > 0.0 or _dodge_left > 0.0:
		return false
	if clip <= 0:
		reload()
		return false
	clip -= 1
	_cooldown = gun.fire_interval
	var from := eye()
	var strength := power()
	if gun.flare_speed > 0.0:
		_fire_flare(gun, strength)
	else:
		_fire_rays(gun, strength)
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, from, gun.noise_range, body)
	if view_model != null:
		view_model.kick()
	if is_local() and mode.view != null:
		mode.view.shake(gun.shake)
	if clip == 0:
		reload()
	return true


## What its gun's damage is multiplied by: its rarity's (S-025, Q3).
func power() -> float:
	var rarity := VersusRarity.of(loadout.weapon, mode.settings.rarities)
	return rarity.damage_multiplier if rarity != null else 1.0


func _fire_rays(gun: VersusWeapon, strength: float) -> void:
	var from := eye()
	var space := body.get_world_3d().direct_space_state
	var struck: BossKit
	var hits := 0
	for direction in HitscanShot.directions(aim(), gun.pellets, gun.spread_when(aiming), _rng):
		var end := from + direction * gun.reach
		var query := PhysicsRayQueryParameters3D.create(from, end, Flare.LAYERS)
		query.exclude = [body.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
			var boss := mode.boss_of(hit.collider as Node)
			if boss != null:
				boss.take_shot(body, end, gun, strength)
				struck = boss
				hits += 1
		mode.add_tracer(muzzle(), end, gun.tracer_color, loadout.weapon.id)
	if struck != null and gun.push > 0.0:
		var share := float(hits) / gun.pellets
		struck.blasted(struck.body.global_position - body.global_position, gun.push * share, 0.0)


func _fire_flare(gun: VersusWeapon, strength: float) -> void:
	var direction := HitscanShot.directions(aim(), 1, gun.spread_when(aiming), _rng)[0]
	var flare := Flare.new()
	flare.mode = mode
	flare.shooter = body
	flare.gun = gun
	flare.power = strength
	flare.gravity = 0.0
	flare.trail = gun.tracer_color
	flare.velocity = direction * gun.flare_speed
	mode.add_flare(flare, eye() + direction * 0.5)


## Aims while its player holds right click with a gun that aims, standing,
## neither reloading nor rolling (T-412): it walks, and its mouse turns,
## slower; VersusView zooms, ViewModel raises the gun to the eye.
func _update_aim() -> void:
	var gun := loadout.gun()
	var now := (
		body is Player
		and gun != null
		and gun.zoom_fov > 0.0
		and vitals.is_standing()
		and not reloading
		and _dodge_left <= 0.0
		and keys.held(PlayerCommands.FLAG_SCAN)
	)
	if now == aiming:
		return
	if not now:
		_let_go_aim()
		return
	aiming = true
	var player := body as Player
	_hip_settings = player.settings
	var slow: PlayerSettings = player.settings.duplicate()
	var slower := mode.settings.aim_speed_scale
	slow.walk_speed *= slower
	slow.sprint_speed = slow.walk_speed
	slow.crouch_speed *= slower
	slow.mouse_sensitivity *= clampf(gun.zoom_fov / mode.settings.view_fov, 0.2, 1.0)
	player.settings = slow
	if view_model != null:
		view_model.aim(true, loadout.weapon.id)


func _let_go_aim() -> void:
	aiming = false
	if _hip_settings != null:
		(body as Player).settings = _hip_settings
		_hip_settings = null
	if view_model != null:
		view_model.aim(false)


## Where its tracers leave from: the gun in its hands, right of and below
## its eyes, a step ahead.
func muzzle() -> Vector3:
	var head: Node3D = body.get_node_or_null("Head")
	var look := head.global_basis if head != null else body.global_basis
	return eye() + look * Vector3(0.25, -0.3, -0.6)


func reload() -> void:
	var gun := loadout.gun()
	if gun == null or reloading or clip >= gun.clip or not vitals.is_standing():
		return
	if loadout.spare_ammo <= 0:
		return
	reloading = true
	_reload_left = gun.reload_time


## Rolls toward direction (flat) if it has the stamina (Q15).
func dodge(direction: Vector3) -> bool:
	if not vitals.is_standing() or _dodge_left > 0.0:
		return false
	direction.y = 0.0
	if direction.length() < 0.01:
		direction = body.global_basis.z  # Backwards when standing still.
	if not stamina.spend(mode.settings.dodge_cost):
		return false
	_dodge_left = mode.settings.dodge_time
	_dodge_velocity = (
		direction.normalized() * mode.settings.dodge_distance / mode.settings.dodge_time
	)
	vitals.shield(mode.settings.dodge_shield_time)
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP, body.global_position, mode.settings.dodge_noise_range, body
	)
	return true


## Thrown by push (the leap's shock wave, Q9): it slides like a roll,
## without its shield.
func knock(push: Vector3) -> void:
	push.y = 0.0
	_dodge_left = mode.settings.dodge_time
	_dodge_velocity = push / mode.settings.dodge_time


## A blow of the boss (Q9); true if it hurt.
func take_blow(damage: int) -> bool:
	if not vitals.hurt(damage):
		return false
	hurt.emit(damage)
	if view_model != null:
		view_model.flash(Color.RED)
	return true


## Lands after a fall of height meters (Q34): a noise, and points lost,
## one less when rolling.
func land(height: float) -> void:
	var settings := mode.settings
	if FallRules.is_loud(settings, height):
		NoiseBus.emit_noise(
			NoiseEvent.Type.FOOTSTEP, body.global_position, settings.fall_noise_range, body
		)
	var damage := FallRules.hunted_damage(settings, height, settings.hunted_health)
	if _dodge_left > 0.0:
		damage = FallRules.after_roll(settings, damage, height)
	if damage > 0 and vitals.hurt(damage, true):
		hurt.emit(damage)
		if view_model != null:
			view_model.flash(Color.RED)


## Forgets the fall under way: it was moved to its start (Q29).
func reset_fall() -> void:
	_fall.reset()


func _physics_process(delta: float) -> void:
	if mode.mirror:
		_show_mirror(delta)
		return
	if is_played():
		keys.update((body as Player).commands)
	_update_aim()
	vitals.update(delta)
	stamina.update(delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			var gun := loadout.gun()
			if gun != null:
				clip += loadout.draw_ammo(gun.clip - clip)
	if view_model != null:
		view_model.speed = Vector2(body.velocity.x, body.velocity.z).length()
		view_model.lower(1.0 if not vitals.is_standing() else (0.4 if reloading else 0.0))
		view_model.visible = not vitals.is_out() and mode.first_person()
	var fallen := _fall.update(body.is_on_floor(), body.global_position.y)
	if fallen > 0.0:
		land(fallen)
	if _dodge_left > 0.0:
		_dodge_left -= delta
		body.move_and_collide(_dodge_velocity * delta)
	if not vitals.is_standing() or mode.is_over():
		if laser != null:
			laser.update(false, delta)
		return
	if is_played():
		_read_commands((body as Player).commands, delta)
	elif not body is Player:
		_think(delta)


## A client (T-381): the room plays; only its arms and its laser beam
## show here, at once.
func _show_mirror(delta: float) -> void:
	keys.update((body as Player).commands)
	_update_aim()  # It walks as slowly as the room makes it.
	if view_model != null:
		view_model.speed = Vector2(body.velocity.x, body.velocity.z).length()
		view_model.lower(1.0 if not vitals.is_standing() else (0.4 if reloading else 0.0))
		view_model.visible = not vitals.is_out() and mode.first_person()
		if _fires_now() and clip > 0 and not reloading:
			view_model.kick()
	if laser != null:
		var battery := laser.battery
		laser.update(vitals.is_standing() and keys.held(PlayerCommands.FLAG_FIRE), delta)
		laser.battery = battery  # The room's.


## The player's keys (T-381), from its commands: the same on this machine
## and on the room.
func _read_commands(commands: PlayerCommands, delta: float) -> void:
	if _fires_now():
		fire()
	if laser != null:
		laser.update(keys.held(PlayerCommands.FLAG_FIRE), delta)
	for slot in VersusLoadout.TOOL_SLOTS:
		if keys.pressed(PlayerCommands.FLAG_TOOL_1 if slot == 0 else PlayerCommands.FLAG_TOOL_2):
			use_tool(slot)
	_hold_interact(keys.held(PlayerCommands.FLAG_INTERACT), delta)
	if keys.pressed(PlayerCommands.FLAG_BREATH):
		reload()
	if keys.pressed(PlayerCommands.FLAG_DODGE):
		dodge(body.global_basis * Vector3(commands.move.x, 0.0, commands.move.y))


## Whether its player's fire key shoots this frame: held for an automatic
## gun (and its cooldown spaces the shots), pressed for the others.
func _fires_now() -> bool:
	var gun := loadout.gun()
	if gun != null and gun.automatic:
		return keys.held(PlayerCommands.FLAG_FIRE)
	return keys.pressed(PlayerCommands.FLAG_FIRE)


## The chest in reach it aims at (or the nearest, for an AI), or null.
func chest_in_reach() -> VersusChest:
	var best: VersusChest
	var best_score := -INF
	for node in body.get_tree().get_nodes_in_group(VersusChest.GROUP):
		var each := node as VersusChest
		var offset := each.global_position + Vector3.UP * 0.3 - eye()
		if offset.length() > mode.settings.chest_reach:
			continue
		var score := -offset.length() if not is_played() else offset.normalized().dot(aim())
		if is_played() and score < 0.6:
			continue
		if score > best_score:
			best = each
			best_score = score
	return best


## Seconds a revive takes: shorter with a medkit (Q13).
func revive_time() -> float:
	var factor := mode.settings.medkit_revive_factor if _medkit_slot() >= 0 else 1.0
	return mode.settings.revive_time * factor


## Interact held: a downed teammate in reach first (Q5), else the chests.
func _hold_interact(held: bool, delta: float) -> void:
	var settings := mode.settings
	var done := revive.update(
		mode.hunters, body.global_position, held, delta, revive_time(), settings.revive_reach, self
	)
	if done != null and done.vitals.revive():
		revives_done += 1
		var slot := _medkit_slot()
		if slot >= 0:
			loadout.spend(slot)
	hold_chest(held and revive.target == null and done == null, delta)


func _medkit_slot() -> int:
	for slot in VersusLoadout.TOOL_SLOTS:
		var item := loadout.tool_in(slot)
		if item != null and item.id == &"medkit":
			return slot
	return -1


func _on_revive_started(_target: HunterKit) -> void:
	NoiseBus.emit_noise(
		NoiseEvent.Type.RESCUE, body.global_position, mode.settings.revive_noise_range, body
	)


## One frame of interact held (held) or not, on the chest in reach (Q30):
## once held long enough, it opens it, then takes what is in it.
func hold_chest(held: bool, delta: float) -> void:
	var target := chest_in_reach() if held else null
	if target != chest or target == null:
		chest = target
		chest_held = 0.0
		if target == null:
			return
	if chest.is_open and (chest.item == null or not (is_played() or _ai_wants(chest.item))):
		chest_held = 0.0
		return
	chest_held += delta
	if chest_held < chest.hold_time(mode.settings):
		return
	chest_held = 0.0
	if not chest.is_open:
		chest.open(body, mode.settings)
	elif chest.item != null:
		chest.set_item(equip(chest.item))


## What an AI prey takes from an open chest: a weapon if it has none, the
## UV laser over a gun, a rarer gun than its own (S-025), a tool in a free
## slot, ammo for its gun.
func _ai_wants(item: VersusItem) -> bool:
	match item.slot:
		VersusItem.Slot.WEAPON:
			return (
				loadout.weapon == null
				or (item.id == &"uv_laser" and not loadout.has_weapon(item.id))
				or (
					item.weapon != null
					and loadout.gun() != null
					and item.rarity > loadout.weapon.rarity
				)
			)
		VersusItem.Slot.AMMO:
			return loadout.gun() != null
	return loadout.tools.size() < VersusLoadout.TOOL_SLOTS


## An AI prey: it goes where PreyFighter says, rolls away from a blow,
## and fires at the boss it sees within range: bursts of its gun (S-025),
## or the UV laser held while it sees it.
func _think(delta: float) -> void:
	_hold_interact(true, delta)
	_steer(delta)
	_ai_dodge()
	var boss := mode.boss
	var alive := boss != null and not boss.health.is_dead()
	if laser != null:
		laser.update(alive and _sees_boss(mode.settings.laser_range), delta)
		return
	if not alive:
		return
	if _ai_burst_left > 0.0:
		_ai_burst_left -= delta
		fire()  # Its cooldown spaces the shots.
		return
	_ai_wait -= delta
	if _ai_wait > 0.0:
		return
	_ai_wait = mode.settings.ai_fire_interval
	if _sees_boss(mode.settings.ai_fire_range):
		_ai_burst_left = mode.settings.ai_burst_time
		var error := deg_to_rad(mode.settings.ai_aim_error)
		_aim_error = Basis.from_euler(
			Vector3(_rng.randf_range(-error, error), _rng.randf_range(-error, error), 0.0)
		)
		fire()


## Sends the Prey towards its goal (Q17): beside a downed teammate, before
## a chest worth opening; back to its own ways without one.
func _steer(delta: float) -> void:
	var prey := body as Prey
	if prey == null or mode.boss == null:
		return
	fighter.update(delta)
	_ai_goal_wait -= delta
	if _ai_goal_wait > 0.0:
		return
	_ai_goal_wait = mode.settings.ai_think_interval
	prey.alarm_distance = mode.settings.ai_keep_distance if loadout.weapon != null else 0.0
	var downed: Array[Vector3] = []
	var mates: Array[Vector3] = []
	for kit in mode.hunters:
		if kit != self and kit.vitals.is_down():
			downed.append(kit.body.global_position)
		elif kit != self and kit.vitals.is_standing():
			mates.append(kit.body.global_position)
	var chests: Array[Vector3] = []
	for node in body.get_tree().get_nodes_in_group(VersusChest.GROUP):
		var each := node as VersusChest
		if not each.is_open or (each.item != null and _ai_wants(each.item)):
			chests.append(each.global_position)
	var own := body.global_position
	var zone_point: Variant = null
	var zone := mode.zone
	if zone != null and zone.must_move_in(own, mode.rules.clock):
		zone_point = zone.inside_point(own, mode.rules.clock + 10.0)
	if zone != null:  # Only what is still inside the zone in a while.
		downed = _inside(downed)
		chests = _inside(chests)
	var goal := fighter.choose(
		own,
		mode.boss.body.global_position,
		downed,
		chests,
		loadout.weapon != null,
		mates,
		zone_point
	)
	if goal == PreyFighter.Goal.NONE:
		if _sent_to != null and prey.brain.state == PreyBrain.State.SEARCH:
			prey.brain.end_detour()
		_sent_to = null
		return
	if prey.brain.state in [PreyBrain.State.FLEE, PreyBrain.State.HIDE]:
		if goal != PreyFighter.Goal.ZONE:
			return  # Away from the boss first, unless out of the zone.
	var side := own - fighter.point
	side.y = 0.0
	var spot := fighter.point + side.normalized() * 0.9 if side.length() > 0.9 else own
	if _sent_to == null or (_sent_to as Vector3).distance_to(spot) > 1.0:
		_sent_to = spot
	if prey.brain.state != PreyBrain.State.SEARCH or prey.brain.target != _sent_to:
		prey.brain.send_to(_sent_to)


## The points of points the zone will still hold in a while.
func _inside(points: Array[Vector3]) -> Array[Vector3]:
	var kept: Array[Vector3] = []
	for each in points:
		if not mode.zone.must_move_in(each, mode.rules.clock, 15.0, 2.0):
			kept.append(each)
	return kept


## Rolls away, sideways, from a blow the boss winds up at it.
func _ai_dodge() -> void:
	var boss := mode.boss
	if boss == null:
		return
	var offset := body.global_position - boss.body.global_position
	offset.y = 0.0
	var windup_claw := boss.move == BossKit.Move.CLAW_WINDUP
	var windup_charge := boss.move == BossKit.Move.CHARGE_WINDUP
	if fighter.should_dodge(windup_claw, windup_charge, offset.length()):
		dodge(offset.cross(Vector3.UP) if windup_charge else offset)


func _sees_boss(reach: float) -> bool:
	var target := mode.boss.body.global_position + Vector3.UP * 1.2
	if eye().distance_to(target) > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye(), target, 1 | 2)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Downed (Q5): a player crawls, an AI prey lies still.
func _on_downed() -> void:
	_let_go_aim()  # Its walking settings back before it crawls.
	revive.reset()
	chest = null
	chest_held = 0.0
	if laser != null:
		laser.update(false, 0.0)
	if body is Player:
		var player := body as Player
		_standing_settings = player.settings
		var crawl: PlayerSettings = player.settings.duplicate()
		crawl.walk_speed = mode.settings.crawl_speed
		crawl.sprint_speed = mode.settings.crawl_speed
		crawl.crouch_speed = mode.settings.crawl_speed
		player.settings = crawl
		_crouched_by_fall = not player.is_sneaking()
		if _crouched_by_fall:
			player.toggle_crouch()
	else:
		body.set_physics_process(false)
		_down_label = Label3D.new()
		_down_label.text = Text.t("VERSUS_DOWN")
		_down_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_down_label.position = Vector3.UP * 2.2
		body.add_child(_down_label)


func _on_revived() -> void:
	if body is Player:
		_stand_up(body as Player)
	else:
		body.set_physics_process(true)
		if _down_label != null:
			_down_label.queue_free()
			_down_label = null


## Out (Q5): it stays where it fell, the others play on.
func _on_out() -> void:
	revive.reset()
	if body is Player:
		_stand_up(body as Player)
		(body as Player).held = true
		return
	if _down_label == null:
		_on_downed()  # Out at once: lies still like a downed one.
	_down_label.text = Text.t("VERSUS_OUT")


func _stand_up(player: Player) -> void:
	if _standing_settings != null:
		player.settings = _standing_settings
		_standing_settings = null
	if _crouched_by_fall:
		player.toggle_crouch()
		_crouched_by_fall = false
