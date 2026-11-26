class_name VersusNet
extends Node
## The Versus online (spec S-024, T-381): what the room tells the clients,
## through the network's mode hook (NetGame.mode_link). The room plays the
## game (VersusMode with its kits on the avatars); a client only shows it:
## its kit and the boss's health copy what the room says.
## Each snapshot carries, for its player (net_snapshot):
##   [clock, boss health, phase, kneel left, rage, fury left, boss position
##   if tracked (Q4) else null, winner, you, boss max health], with you,
##   for a hunted:
##   [health, state, down left, weapon id, clip, spare ammo, reloading,
##   battery, tools [[id, uses], ...], prompt, revives done, weapon rarity];
##   for the boss:
##   [move, leap wait, prompt]; prompt as KitPrompts gives it.
## Events (send_mode_event), as [Event, ...]:
##   [CHESTS, [[position, item id, open, rarity], ...]]: the chests, when
##   they change;
##   [SHOT, position, velocity, gravity, trail]: a flare fired (the
##   precision rifle's: no gravity, a trail), the clients show their copy;
##   [FLASH, point]: a flash grenade went off there (S-025);
##   [BANNER, text key, values]: the banner of an event (S-025, Q4);
##   [HIT, face, point, damage, steady]: to the shooter, its hit marker
##   (Q21) and its damage number (S-025);
##   [TRACER, from, to, color]: a gun's shot (S-025), its tracer;
##   [LIGHTS_OUT]: the cry of phase 2 (Q8);
##   [LEAP, target]: the boss leaps, its shadow shows there (Q9);
##   [END, winner, dawn, clock, rows, mvp seat]: the end screen (Q28), rows
##   as VersusStats.rows gives them.

enum Event { CHESTS, SHOT, HIT, LIGHTS_OUT, LEAP, END, TRACER, FLASH, BANNER }

var mode: VersusMode
var net: NetGame
var _sent_chests := []


func _init(p_mode: VersusMode, p_net: NetGame) -> void:
	mode = p_mode
	net = p_net
	name = "VersusNet"
	net.mode_link = self


func _exit_tree() -> void:
	if is_instance_valid(net) and net.mode_link == self:
		net.mode_link = null


# --- Room side --------------------------------------------------------------


## What the player in seat is sent with each snapshot.
func net_snapshot(seat: int) -> Array:
	var health := mode.boss.health
	var tracked: Variant = null
	if mode.rules.boss_tracked():
		tracked = mode.boss.body.global_position
	var you: Array = []
	var node := _avatar_of(seat)
	if node == mode.boss.body:
		you = [mode.boss.move, mode.boss.leap.wait, KitPrompts.of_boss(mode.boss)]
	else:
		var kit := mode.kit_of(node)
		if kit != null:
			you = hunter_state(kit)
	return [
		mode.rules.clock,
		health.health,
		health.phase,
		health.kneel_left,
		health.rage,
		health.fury_left,
		tracked,
		mode.rules.winner,
		you,
		health.max_health,
	]


## What a hunted's player sees of its kit.
static func hunter_state(kit: HunterKit) -> Array:
	var tools := []
	for slot in kit.loadout.tools.size():
		tools.append([String(kit.loadout.tools[slot].id), kit.loadout.uses[slot]])
	var weapon := kit.loadout.weapon
	return [
		kit.vitals.health,
		kit.vitals.state,
		kit.vitals.down_left,
		String(weapon.id) if weapon != null else "",
		kit.clip,
		kit.loadout.spare_ammo,
		kit.reloading,
		kit.laser.battery if kit.laser != null else 0.0,
		tools,
		KitPrompts.of_hunter(kit),
		kit.revives_done,
		weapon.rarity if weapon != null else 0,
	]


## The events a player whose map is ready needs: the chests as they are.
func net_ready_events() -> Array:
	return [[Event.CHESTS, chest_values()]]


func chest_values() -> Array:
	var values := []
	for node in get_tree().get_nodes_in_group(VersusChest.GROUP):
		var chest := node as VersusChest
		var id := String(chest.item.id) if chest.item != null else ""
		var rarity := chest.item.rarity if chest.item != null else 0
		values.append([chest.global_position, id, chest.is_open, rarity])
	return values


## Room side, each frame: the chests to everyone when they changed.
func _physics_process(_delta: float) -> void:
	if mode.mirror:
		return
	var values := chest_values()
	if values != _sent_chests:
		_sent_chests = values
		net.send_mode_event([Event.CHESTS, values])


func send(payload: Array, seat := -1) -> void:
	net.send_mode_event(payload, seat)


func seat_of(node: Node3D) -> int:
	return net.seat_of(node)


func _avatar_of(seat: int) -> Node3D:
	for place in net.avatars:
		if net.seats[place] == seat:
			return net.avatars[place]
	return null


# --- Client side ------------------------------------------------------------


func apply_net_snapshot(value: Variant) -> void:
	if not value is Array or (value as Array).size() < 10:
		return
	var values: Array = value
	var rules := mode.rules
	rules.clock = values[0]
	var health := mode.boss_health()
	health.max_health = values[9]
	health.health = values[1]
	health.phase = clampi(values[2], 0, maxi(mode.settings.phases.size() - 1, 0))
	health.kneel_left = values[3]
	health.rage = values[4]
	health.fury_left = values[5]
	mode.tracked_at = values[6]
	rules.winner = values[7]
	var you: Array = values[8]
	if mode.boss != null and you.size() >= 3:
		mode.boss.move = you[0]
		mode.boss.leap.wait = you[1]
		mode.boss.mirror_prompt = you[2]
	elif not mode.hunters.is_empty() and you.size() >= 12:
		apply_hunter_state(mode.hunters[0], you)


## Copies what the room says of the hunted's kit onto kit.
func apply_hunter_state(kit: HunterKit, you: Array) -> void:
	var vitals := kit.vitals
	var was := vitals.state
	if you[0] < vitals.health:
		kit.hurt.emit(vitals.health - you[0])  # The red edge here too.
	vitals.health = you[0]
	vitals.state = clampi(you[1], 0, HuntedVitals.State.size() - 1) as HuntedVitals.State
	vitals.down_left = you[2]
	if vitals.state != was:  # The same crawl, stand up or stay as on the room.
		match vitals.state:
			HuntedVitals.State.DOWN:
				vitals.downed.emit()
			HuntedVitals.State.STANDING:
				vitals.revived.emit()
			HuntedVitals.State.OUT:
				vitals.out.emit()
	var weapon := mode.item(StringName(you[3]), you[11])
	if weapon != kit.loadout.weapon:
		kit.show_weapon(weapon)
	kit.clip = you[4]
	kit.loadout.spare_ammo = you[5]
	kit.reloading = you[6]
	if kit.laser != null:
		kit.laser.battery = you[7]
	kit.loadout.tools.clear()
	kit.loadout.uses.clear()
	for entry: Array in you[8]:
		var item := mode.item(StringName(entry[0]))
		if item != null:
			kit.loadout.tools.append(item)
			kit.loadout.uses.append(entry[1])
	kit.mirror_prompt = you[9]
	kit.revives_done = you[10]


func apply_net_event(payload: Array) -> void:
	if payload.is_empty():
		return
	match payload[0]:
		Event.CHESTS when payload.size() == 2:
			_mirror_chests(payload[1])
		Event.SHOT when payload.size() == 5:
			var flare := Flare.new()
			flare.mode = mode
			flare.velocity = payload[2]
			flare.gravity = payload[3]
			flare.trail = payload[4]
			mode.add_flare(flare, payload[1])
		Event.HIT when payload.size() == 5 and mode.hud != null:
			mode.hud.show_hit(payload[1])
			mode.hud.show_damage(payload[2], payload[3], payload[1], payload[4])
		Event.TRACER when payload.size() == 4:
			mode.add_tracer(payload[1], payload[2], payload[3])
		Event.FLASH when payload.size() == 2:
			mode.show_flash(payload[1])
		Event.BANNER when payload.size() == 3 and mode.hud != null:
			mode.hud.show_banner(payload[1], payload[2])
		Event.LIGHTS_OUT:
			mode.put_lights_out()
		Event.LEAP when payload.size() == 2:
			mode.show_leap(payload[1])
		Event.END when payload.size() == 6:
			mode.show_online_end(payload[1], payload[2], payload[3], payload[4], payload[5])


## The chests as the room has them: moved, added, opened, emptied.
func _mirror_chests(values: Array) -> void:
	var chests := get_tree().get_nodes_in_group(VersusChest.GROUP)
	for i in values.size():
		var entry: Array = values[i]
		var chest: VersusChest
		if i < chests.size():
			chest = chests[i]
		else:
			chest = mode.add_chest(entry[0], null)
		chest.global_position = entry[0]
		chest.mirror(entry[2], mode.item(StringName(entry[1]), entry[3]))
