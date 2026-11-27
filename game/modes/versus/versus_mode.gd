class_name VersusMode
extends Node
## The Versus mode (spec S-024, T-372 to T-374): the monster becomes a boss
## with a health bar, the hunted fight it with guns (S-025). A child of the map,
## added by GameMap when GameSession.mode is VERSUS (the only line outside
## this folder that knows it). It gives each hunted (Player, Prey) a
## HunterKit and each monster (Monster, MonsterAvatar) a BossKit, runs the
## rules (VersusRules) and shows the HUD (VersusHud) to the local player.
## Dawn near (Q3): a siren, and the boss enters its last phase. The end
## (Q1, Q28): slow motion and a camera turning around the fallen boss, then
## the end screen (VersusEndScreen) with what each hunted did (VersusStats).
## Solo in the test room or the cité ("Jouer seul › Versus", T-375), or
## online (T-381): the room plays it like solo, with the humans' avatars
## driven by their commands, and VersusNet tells the clients; a client
## (mirror) only shows it: a kit on its own avatar copying the room, the
## chests, the flares, the end.
## To remove the mode: docs/MODULES.md, "Le mode Versus".

signal finished(winner: VersusRules.Winner)

const MODE := GameModes.VERSUS
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")
## How far in front of a hunted's start its first chest stands, in meters.
const FIRST_CHEST_DISTANCE := 2.0

var settings: VersusSettings = SETTINGS
var rules: VersusRules
var boss: BossKit
var hunters: Array[HunterKit] = []
var hud: VersusHud
var stats: VersusStats
## The view from behind this machine's player (S-025, T-402), or null.
var view: VersusView
var end_screen: VersusEndScreen
## Whether dawn near was announced (Q3).
var dawn_announced := false
## The arena of this map (Q24), or null: the whole map (the test room).
var arena: VersusArena
## The zone that shrinks (S-025, Q6), or null without an arena.
var zone: VersusZone
## Online (T-381): the map's NetGame, or null in solo; mirror on a client.
var net: NetGame
var mirror := false
var link: VersusNet
## The guns in the hunted's hands (T-409), or null.
var held_guns: HeldGuns
## Client side: where the room says the tracked boss is (Q4), or null.
var tracked_at: Variant = null
## The boss's shadow where it lands (Q9).
var leap_shadow: MeshInstance3D
var _mirror_health: BossHealth
var _leap_shadow_left := 0.0
var _ended := false
var _lit: Array[Flare] = []
## Seconds left before the zone hurts each hunted outside it again.
var _zone_ticks := {}
## The zone step whose warning and start were announced.
var _zone_warned := -1
var _zone_started := -1
## The copies of the guns by rarity (item).
var _rare_items := {}
var _slowmo_left := 0.0
var _end_left := -1.0
var _orbit: Camera3D
var _orbit_angle := 0.0


## Whether the game being started is a Versus one.
static func is_on() -> bool:
	return GameSession.mode == MODE


func _ready() -> void:
	name = "VersusMode"
	_setup.call_deferred()  # Once the map's role part has placed everyone.


func _setup() -> void:
	stats = VersusStats.new(settings)
	net = get_parent().get(&"net")
	mirror = net != null and not net.is_room
	arena = arena_of(get_parent().scene_file_path)
	if arena != null:
		var builder := ArenaBuilder.new(arena)
		get_parent().add_child(builder)
		builder.use_navigation(get_parent())
	_open_doors()
	add_child(VersusDaylight.new(self))
	if arena != null:
		zone = VersusZone.new(settings, arena.bounds)
		add_child(ZoneWall.new(self, zone))
	leap_shadow = _make_shadow()
	add_child(leap_shadow)
	end_screen = VersusEndScreen.new()
	end_screen.online = net != null
	add_child(end_screen)
	held_guns = HeldGuns.new(self)
	add_child(held_guns)
	if mirror:
		_setup_mirror()
		return
	var short_clock := OS.get_environment("ECHO_VERSUS_TIME")  # The CI's online test.
	if short_clock.is_valid_float():
		settings = settings.duplicate()
		settings.match_time = float(short_clock)
	for node in _hunted_nodes():
		var kit := HunterKit.new(self)
		hunters.append(kit)
		node.add_child(kit)
	for node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		if node.is_queued_for_deletion():
			continue  # Online: the AI monster a human's avatar replaced.
		var monster_settings: MonsterSettings = node.get(&"settings")
		monster_settings.catch_distance = 0.0  # Its own copy: blows, not catches.
		boss = BossKit.new(self)
		node.add_child(boss)
		break
	_dress_bosses()
	if boss == null:
		push_warning("Versus: no monster in the map")
		return
	if arena != null:
		_place_everyone()
	_gear_up()
	boss.health.phase_changed.connect(_on_phase_changed)
	NoiseBus.noise_emitted.connect(_on_noise)
	rules = VersusRules.new(settings, boss.health)
	for kit in hunters:
		rules.hunted.append(kit.vitals)
		kit.vitals.downed.connect(announce.bind("VERSUS_DOWN_BANNER", []))
		kit.vitals.revived.connect(announce.bind("VERSUS_REVIVED_BANNER", []))
		kit.vitals.out.connect(announce.bind("VERSUS_OUT_BANNER", []))
	if net != null:
		link = VersusNet.new(self, net)
		add_child(link)
	if net == null or not net.is_room:
		hud = VersusHud.new(self)
		add_child(hud)
		_add_view()


## A client (T-381): a kit on its own avatar, the rest from the room.
func _setup_mirror() -> void:
	var own := net.own
	if own is Player:
		var kit := HunterKit.new(self)
		hunters.append(kit)
		own.add_child(kit)
	elif own is MonsterAvatar:
		boss = BossKit.new(self)
		own.add_child(boss)
	_mirror_health = boss.health if boss != null else BossHealth.new(settings, LobbyState.SEATS - 1)
	_dress_bosses()
	rules = VersusRules.new(settings, boss_health())
	link = VersusNet.new(self, net)
	add_child(link)
	hud = VersusHud.new(self)
	add_child(hud)
	_add_view()


## The boss's look (S-025, Q8) on each monster of the map: its own kit's,
## or on a client the room's boss as shown here.
func _dress_bosses() -> void:
	for node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		if node.is_queued_for_deletion() or node.has_node("BossLook"):
			continue
		var look := BossLook.new(self)
		node.add_child(look)
		if boss != null and node == boss.body:
			boss.look = look


## The view from behind this machine's player (S-025, Q1), hunted or boss.
func _add_view() -> void:
	var own: CharacterBody3D = null
	var kit := local_hunter()
	if kit != null:
		own = kit.body
	elif boss != null and boss.is_local():
		own = boss.body
	if own != null:
		view = VersusView.new(settings, own)
		add_child(view)


## Whether this machine's player sees through its own eyes (its arms show).
func first_person() -> bool:
	return view == null or view.first_person


## Every door of the map open for good (S-025, Q5): one passes everywhere,
## on the room and on each client alike.
func _open_doors() -> void:
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).hold_open()


## The boss's health: its kit's, or on a hunted's client the room's copy.
func boss_health() -> BossHealth:
	if mirror:
		return _mirror_health
	return boss.health if boss != null else null


## Where the tracked boss is (Q4), or null while it is not tracked.
func tracked_position() -> Variant:
	if mirror:
		return tracked_at
	if rules != null and boss != null and rules.boss_tracked():
		return boss.body.global_position
	return null


## The kit of a hunted's body, or null.
func kit_of(node: Node) -> HunterKit:
	for kit in hunters:
		if kit.body == node:
			return kit
	return null


## The item of the settings with id, or null.
## The item id of rarity (S-025, T-404): the one of settings.items for
## common, else its copy of that rarity (one copy each, so that the room and
## the clients name it alike).
func item(id: StringName, rarity := 0) -> VersusItem:
	var base: VersusItem
	for each in settings.items:
		if each.id == id:
			base = each
	if base == null or rarity <= 0 or base.slot != VersusItem.Slot.WEAPON:
		return base
	var key := "%s:%d" % [id, rarity]
	if not _rare_items.has(key):
		var copy: VersusItem = base.duplicate()
		copy.rarity = mini(rarity, settings.rarities.size() - 1)
		_rare_items[key] = copy
	return _rare_items[key]


## What a chest holds (Q31): an item drawn by weight and, for a gun, its
## rarity (S-025, Q3), better in the chests of a new phase.
func _draw_item(rng: RandomNumberGenerator, phase: bool) -> VersusItem:
	var drawn := VersusLoadout.draw(settings.items, rng, phase)
	if drawn == null or drawn.slot != VersusItem.Slot.WEAPON:
		return drawn
	return item(drawn.id, VersusRarity.draw(settings.rarities, rng, phase))


## The boss leaps onto target (Q9): its shadow shows there while it flies,
## for everyone.
func show_leap(target: Vector3) -> void:
	leap_shadow.global_position = target + Vector3.UP * 0.05
	leap_shadow.visible = true
	_leap_shadow_left = settings.leap_time
	if link != null and not mirror:
		link.send([VersusNet.Event.LEAP, target])


## The arena of the map at map_path, or null.
func arena_of(map_path: String) -> VersusArena:
	for each in settings.arenas:
		if each.map_path == map_path:
			return each
	return null


## Everyone to their start (Q29): the hunted side by side, the boss away.
func _place_everyone() -> void:
	for i in hunters.size():
		_place(hunters[i].body, arena.hunted_spawn(i), arena.hunted_yaw)
		hunters[i].reset_fall()
	_place(boss.body, arena.boss_spawn, arena.boss_yaw)
	boss.reset_fall()


func _place(body: Node3D, point: Vector3, yaw: float) -> void:
	body.global_position = point
	body.rotation.y = yaw
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


## The start (Q29): in an arena, a chest with the launcher by each player
## hunted and the arena's first chests; the AI preys (until they look for
## chests, T-383) and the test room get their launcher at once.
func _gear_up() -> void:
	for kit in hunters:
		if arena == null or not kit.is_played():
			kit.equip(settings.first_weapon)
			continue
		var start := kit.body.global_position
		var toward := arena.boss_spawn - start
		toward.y = 0.0
		add_chest(start + toward.normalized() * FIRST_CHEST_DISTANCE, settings.first_weapon)
	if arena != null:
		_add_arena_chests(0, settings.arena_chests, false)


## A chest holding item at point.
func add_chest(point: Vector3, item: VersusItem) -> VersusChest:
	var chest := VersusChest.new(item)
	chest.rarities = settings.rarities
	add_child(chest)
	chest.global_position = point
	return chest


func _add_arena_chests(from: int, count: int, phase: bool) -> void:
	for i in range(from, mini(from + count, arena.chest_spots.size())):
		add_chest(arena.chest_spots[i], _draw_item(get_parent().rng, phase))


## A new phase (Q32): new chests, better ones; the cry of the phase that
## says so puts the lights out (Q8).
func _on_phase_changed(index: int) -> void:
	var phase := boss.health.current_phase()
	if phase != null and index > 0:
		announce("VERSUS_PHASE_BANNER", [index + 1, phase.name_key])
	if phase != null and phase.lights_out:
		put_lights_out()
		if link != null:
			link.send([VersusNet.Event.LIGHTS_OUT])
	if arena != null and index > 0:
		var from := settings.arena_chests + (index - 1) * settings.phase_chests
		_add_arena_chests(from, settings.phase_chests, true)


## The lights of the arena go out for good (Q8): its lamps (in the test
## room, every lamp of the map) but not the flares nor what someone carries,
## and the night gets darker. Returns how many went out.
func put_lights_out() -> int:
	var map := get_parent()
	var carriers: Array[Node] = []
	if boss != null:  # A hunted's client has no boss kit.
		carriers.append(boss.body)
	for kit in hunters:
		carriers.append(kit.body)
	var count := 0
	for node in map.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or not light.visible or is_ancestor_of(light):
			continue
		if carriers.any(func(carrier: Node) -> bool: return carrier.is_ancestor_of(light)):
			continue
		if arena != null and not arena.contains(light.global_position):
			continue
		light.visible = false
		count += 1
	for node in map.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world.environment != null:
			world.environment = world.environment.duplicate()
			world.environment.ambient_light_energy *= settings.lights_out_ambient
	return count


## A firecracker going off by the boss hurts it (Q13).
func _on_noise(event: NoiseEvent) -> void:
	if event.type != NoiseEvent.Type.FIRECRACKER or boss == null or is_over():
		return
	if event.position.distance_to(boss.body.global_position) <= settings.firecracker_radius:
		boss.health.take_hit(settings.firecracker_damage, settings.firecracker_poise)
		boss.hit_taken.emit(false)


## The kit of the hunted played on this machine, or null.
func local_hunter() -> HunterKit:
	for kit in hunters:
		if kit.is_local():
			return kit
	return null


## The boss's kit if node is the boss (a flare hit it), else null.
## The boss kit whose body (or hitbox, BossLook) node is, or null.
func boss_of(node: Node) -> BossKit:
	if boss == null or mirror or node == null:
		return null
	if node == boss.body or (boss.look != null and node == boss.look.hitbox):
		return boss
	return null


## The standing hunted nearest to point, or null.
func nearest_standing(point: Vector3) -> HunterKit:
	var best: HunterKit
	for kit in hunters:
		if not kit.vitals.is_standing():
			continue
		if (
			best == null
			or (
				kit.body.global_position.distance_to(point)
				< best.body.global_position.distance_to(point)
			)
		):
			best = kit
	return best


## Adds a flare at position; only the newest flare_lights keep their light.
func add_flare(flare: Flare, at: Vector3) -> void:
	add_child(flare)
	flare.global_position = at
	if link != null and not mirror:
		link.send([VersusNet.Event.SHOT, at, flare.velocity, flare.gravity, flare.trail])
	var lit_now: Array[Flare] = []
	for each: Variant in _lit:
		if is_instance_valid(each):  # Flares that went out are freed.
			lit_now.append(each)
	_lit = lit_now
	_lit.append(flare)
	while _lit.size() > settings.flare_lights:
		_lit.pop_front().light.visible = false


## A shot of shooter hit the boss at point (Q21, S-025): the shooter's hit
## marker and damage number (steady: the UV laser's beam, whose numbers
## add up).
func on_boss_hit(
	_kit: BossKit, shooter: Node3D, face: bool, taken: float, point := Vector3.ZERO, steady := false
) -> void:
	stats.on_hit(shooter, face, taken)
	if link != null and shooter != null and link.seat_of(shooter) > 0:
		link.send([VersusNet.Event.HIT, face, point, taken, steady], link.seat_of(shooter))
	if hud != null and local_hunter() != null and shooter == local_hunter().body:
		hud.show_hit(face)
		hud.show_damage(point, taken, face, steady)


## A flash grenade's burst at point (S-025, T-404), here and on the clients.
func show_flash(point: Vector3) -> void:
	var burst := FlashBurst.new(settings.flash_radius)
	add_child(burst)
	burst.global_position = point
	if link != null and not mirror:
		link.send([VersusNet.Event.FLASH, point])


## A shot's tracer from from to to (S-025, T-403), here and on the clients.
func add_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	add_child(Tracer.between(from, to, color))
	if link != null and not mirror:
		link.send([VersusNet.Event.TRACER, from, to, color])


func is_over() -> bool:
	return rules == null or rules.winner != VersusRules.Winner.NONE


func _physics_process(delta: float) -> void:
	if _leap_shadow_left > 0.0:
		_leap_shadow_left -= delta
		leap_shadow.visible = _leap_shadow_left > 0.0
	if rules == null:
		return
	if mirror:
		if rules.winner != VersusRules.Winner.NONE and not _ended:
			_on_end()  # The room says it is over: the same slow motion here.
	elif rules.winner == VersusRules.Winner.NONE:
		_hurt_outside_zone(delta)
		_announce_zone()
		if rules.update(delta) != VersusRules.Winner.NONE:
			_on_end()
		elif rules.dawn_near() and not dawn_announced:
			_announce_dawn()
		return
	if not _ended:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _orbit != null:
		_turn_orbit(real)
	if _slowmo_left > 0.0:
		_slowmo_left -= real
		if _slowmo_left <= 0.0:
			Engine.time_scale = 1.0
	if _end_left > 0.0 and not mirror:
		_end_left -= real
		if _end_left <= 0.0:
			_finish()


## The game is over: whoever listens (the test room plays again) decides
## what comes next; with nobody (a game in the cité), the end screen.
func _finish() -> void:
	if net != null:
		_finish_online()
		return
	var handled := not finished.get_connections().is_empty()
	finished.emit(rules.winner)
	if not handled:
		Engine.time_scale = 1.0
		if hud != null:
			hud.visible = false
		end_screen.show_result(self)


## The room (T-381): the end screen's values to everyone, then back to the
## lobby, as at the end of a Hunt.
func _finish_online() -> void:
	Engine.time_scale = 1.0
	var mvp := stats.mvp(hunters)
	(
		link
		. send(
			[
				VersusNet.Event.END,
				rules.winner,
				rules.time_left() <= 0.0,
				rules.clock,
				stats.rows(hunters, link.seat_of),
				link.seat_of(mvp.body) if mvp != null else -1,
			]
		)
	)
	get_tree().create_timer(NetSession.settings.end_return_delay).timeout.connect(
		NetSession.end_game
	)


## A client (T-381): the end screen with what the room sent.
func show_online_end(winner: int, dawn: bool, clock: float, rows: Array, mvp_seat: int) -> void:
	Engine.time_scale = 1.0
	if hud != null:
		hud.visible = false
	var own_seat := GameSession.online_seat
	end_screen.show_values(
		VersusEndScreen.title_key(winner as VersusRules.Winner, dawn, boss != null),
		clock,
		VersusStats.lines_of(rows, own_seat),
		VersusStats.seat_name(mvp_seat, own_seat) if mvp_seat >= 0 else ""
	)


## Outside the zone (S-025, Q6): a hunted loses a point every
## zone_hunted_tick seconds, the boss a share of its health each second.
func _hurt_outside_zone(delta: float) -> void:
	if zone == null:
		return
	var clock := rules.clock
	for kit in hunters:
		if not kit.vitals.is_standing() or not zone.is_outside(kit.body.global_position, clock):
			_zone_ticks[kit] = settings.zone_hunted_tick
			continue
		_zone_ticks[kit] = _zone_ticks.get(kit, settings.zone_hunted_tick) - delta
		if _zone_ticks[kit] <= 0.0:
			_zone_ticks[kit] = settings.zone_hunted_tick
			if kit.vitals.hurt(1, true):
				kit.hurt.emit(1)
	if boss != null and zone.is_outside(boss.body.global_position, clock):
		boss.health.take_hit(boss.health.max_health * settings.zone_boss_share * delta)


## The banner says when the zone is about to shrink, then that it shrinks.
func _announce_zone() -> void:
	if zone == null:
		return
	var next := zone.next_step(rules.clock)
	var step: int = next[0]
	var wait: float = next[1]
	if wait > 0.0 and wait <= settings.zone_warning and _zone_warned < step:
		_zone_warned = step
		announce("VERSUS_ZONE_SOON", [ceili(wait)])
	elif wait == 0.0 and _zone_started < step:
		_zone_started = step
		announce("VERSUS_ZONE_SHRINKS")


## A banner for everyone (S-025, Q4): text key and its values.
func announce(key: String, values: Array = []) -> void:
	if hud != null:
		hud.show_banner(key, values)
	if link != null and not mirror:
		link.send([VersusNet.Event.BANNER, key, values])


## Dawn is near (Q3): a siren, and the boss enters its last phase.
func _announce_dawn() -> void:
	dawn_announced = true
	announce("VERSUS_DAWN_NEAR")
	NoiseBus.emit_noise(
		NoiseEvent.Type.SIREN, boss.body.global_position, settings.dawn_siren_range, null
	)
	boss.health.enter_phase(settings.phases.size() - 1)


func _on_end() -> void:
	_ended = true
	if rules.winner == VersusRules.Winner.HUNTED:
		Engine.time_scale = settings.kill_slowmo_scale  # The killing blow (Q1).
		_slowmo_left = settings.kill_slowmo_time
		_start_orbit()
	_end_left = settings.end_delay + settings.kill_slowmo_time
	if hud != null:
		hud.show_end(rules.winner)


## A camera turning around the fallen boss, seen by all (Q1).
func _start_orbit() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or boss == null:  # A hunted's client has no boss kit.
		return
	_orbit = Camera3D.new()
	_orbit.name = "OrbitCamera"
	_orbit.fov = camera.fov
	_orbit.far = camera.far
	_orbit.cull_mask = camera.cull_mask
	add_child(_orbit)
	var offset := camera.global_position - boss.body.global_position
	_orbit_angle = atan2(offset.x, offset.z)
	_turn_orbit(0.0)
	_orbit.make_current()


func _turn_orbit(real_delta: float) -> void:
	_orbit_angle += TAU * settings.orbit_turns * real_delta
	var centre := boss.body.global_position + Vector3.UP
	var around := Vector3(sin(_orbit_angle), 0.0, cos(_orbit_angle)) * settings.orbit_distance
	_orbit.global_position = centre + around + Vector3.UP * settings.orbit_height
	_orbit.look_at(centre, Vector3.UP)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.disconnect(_on_noise)


func _hunted_nodes() -> Array[Node]:
	var found: Array[Node] = []
	var map := get_parent()
	var player: Variant = map.get(&"player")
	if player is Player and is_instance_valid(player) and (player as Node).is_inside_tree():
		found.append(player)
	var room: Variant = map.get(&"room")
	if room != null:
		for each: Node in room.online_hunted:  # Online (T-381): the humans' too.
			if each not in found:
				found.append(each)
	for prey in get_tree().get_nodes_in_group(Prey.GROUP):
		if prey not in found:
			found.append(prey)
	return found


func _make_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "LeapShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = settings.leap_radius
	disc.bottom_radius = settings.leap_radius
	disc.height = 0.02
	disc.radial_segments = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = material
	shadow.mesh = disc
	shadow.top_level = true
	shadow.visible = false
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow
