class_name HunterKit
extends Node
## A hunted's Versus kit (spec S-024, Q5, Q13 to Q15, Q29 to Q31, T-372,
## T-377): its health (HuntedVitals), stamina, what it carries
## (VersusLoadout: a weapon, two tools, spare flares) and its dodge roll,
## plus, for the player, the first-person arms. A child of a Player or a
## Prey, added by VersusMode. It starts empty-handed (Q29) and gears up at
## the chests (VersusChest). The player's keys: left click fires (held for
## the UV laser), R reloads, Space rolls, gadget_1 and gadget_2 use the
## tools (HunterTools), interact held revives a downed teammate (Q5,
## DownedHold), else opens a chest or takes from it. Downed, it crawls;
## out, it stays where it fell.
## An AI prey fires by itself at the boss when it sees it.

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
var view_model: ViewModel
var _cooldown := 0.0
var _reload_left := 0.0
var _dodge_left := 0.0
var _dodge_velocity := Vector3.ZERO
var _ai_wait := 0.0
var _down_label: Label3D
var _fall := FallWatch.new()
## The player's own settings while it crawls (downed).
var _standing_settings: PlayerSettings
var _crouched_by_fall := false


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "HunterKit"


func _ready() -> void:
	body = get_parent()
	vitals = HuntedVitals.new(mode.settings)
	stamina = Stamina.new(mode.settings)
	vitals.downed.connect(_on_downed)
	vitals.revived.connect(_on_revived)
	vitals.out.connect(_on_out)
	revive.started.connect(_on_revive_started)
	if is_local():
		var camera := body.get_viewport().get_camera_3d()
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
	if item.id == &"flare_launcher":
		clip = mode.settings.flare_clip
		if first:
			loadout.spare_flares += mode.settings.start_spare_flares
	reloading = false
	if laser != null:
		laser.queue_free()
		laser = null
	if item.id == &"uv_laser":
		laser = UvLaser.new(self)
		add_child(laser)
	if view_model != null:
		view_model.set_weapon(item.id)
	return left


## A client (T-381): shows weapon in its hands, as the room says it took it.
func show_weapon(weapon: VersusItem) -> void:
	loadout.weapon = weapon
	if laser != null:
		laser.queue_free()
		laser = null
	if weapon != null and weapon.id == &"uv_laser":
		laser = UvLaser.new(self)
		add_child(laser)
	if view_model != null:
		view_model.set_weapon(weapon.id if weapon != null else &"")


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


## Its eyes, where its flares leave from.
func eye() -> Vector3:
	return body.call(&"get_eye_position")


## Where it aims: the camera for the player here, its commands' look for
## one played on the room, the boss for an AI.
func aim() -> Vector3:
	if is_local():
		return -body.get_viewport().get_camera_3d().global_basis.z
	if is_played():
		var commands := (body as Player).commands
		return -Basis.from_euler(Vector3(commands.pitch, commands.yaw, 0.0)).z
	var boss := mode.boss
	if boss == null:
		return -body.global_basis.z
	var target := boss.body.global_position + Vector3.UP * 1.2
	var distance := eye().distance_to(target)
	var flight := distance / mode.settings.flare_speed
	if laser == null:
		target.y += 0.5 * mode.settings.flare_gravity * flight * flight  # Its drop.
	return (target - eye()).normalized()


## Fires a flare if it can; true if one left.
func fire() -> bool:
	if not loadout.has_weapon(&"flare_launcher"):
		return false
	if not vitals.is_standing() or reloading or _cooldown > 0.0 or _dodge_left > 0.0:
		return false
	if clip <= 0:
		reload()
		return false
	clip -= 1
	_cooldown = mode.settings.flare_cooldown
	var direction := aim()
	var flare := Flare.new()
	flare.mode = mode
	flare.shooter = body
	flare.velocity = direction * mode.settings.flare_speed
	mode.add_flare(flare, eye() + direction * 0.5)
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, eye(), mode.settings.shot_noise_range, body)
	if view_model != null:
		view_model.kick()
	if clip == 0:
		reload()
	return true


func reload() -> void:
	if reloading or clip >= mode.settings.flare_clip or not vitals.is_standing():
		return
	if not loadout.has_weapon(&"flare_launcher") or loadout.spare_flares <= 0:
		return
	reloading = true
	_reload_left = mode.settings.reload_time


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
	vitals.update(delta)
	stamina.update(delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			clip += loadout.draw_flares(mode.settings.flare_clip - clip)
	if view_model != null:
		view_model.speed = Vector2(body.velocity.x, body.velocity.z).length()
		view_model.lower(1.0 if not vitals.is_standing() else (0.4 if reloading else 0.0))
		view_model.visible = not vitals.is_out()
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
	if view_model != null:
		view_model.speed = Vector2(body.velocity.x, body.velocity.z).length()
		view_model.lower(1.0 if not vitals.is_standing() else (0.4 if reloading else 0.0))
		view_model.visible = not vitals.is_out()
		if keys.pressed(PlayerCommands.FLAG_FIRE) and clip > 0 and not reloading:
			view_model.kick()
	if laser != null:
		var battery := laser.battery
		laser.update(vitals.is_standing() and keys.held(PlayerCommands.FLAG_FIRE), delta)
		laser.battery = battery  # The room's.


## The player's keys (T-381), from its commands: the same on this machine
## and on the room.
func _read_commands(commands: PlayerCommands, delta: float) -> void:
	if keys.pressed(PlayerCommands.FLAG_FIRE):
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
## UV laser over the flares, a tool in a free slot, flares.
func _ai_wants(item: VersusItem) -> bool:
	match item.slot:
		VersusItem.Slot.WEAPON:
			return (
				loadout.weapon == null
				or (item.id == &"uv_laser" and not loadout.has_weapon(item.id))
			)
		VersusItem.Slot.AMMO:
			return loadout.has_weapon(&"flare_launcher")
	return loadout.tools.size() < VersusLoadout.TOOL_SLOTS


## An AI prey fires at the boss it sees within range: flares now and
## then, or the UV laser held while it sees it.
func _think(delta: float) -> void:
	_hold_interact(true, delta)
	var boss := mode.boss
	var alive := boss != null and not boss.health.is_dead()
	if laser != null:
		laser.update(alive and _sees_boss(mode.settings.laser_range), delta)
		return
	_ai_wait -= delta
	if _ai_wait > 0.0 or not alive:
		return
	_ai_wait = mode.settings.ai_fire_interval
	if _sees_boss(mode.settings.ai_fire_range):
		fire()


func _sees_boss(reach: float) -> bool:
	var target := mode.boss.body.global_position + Vector3.UP * 1.2
	if eye().distance_to(target) > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye(), target, 1 | 2)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Downed (Q5): a player crawls, an AI prey lies still.
func _on_downed() -> void:
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
