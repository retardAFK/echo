class_name Prey
extends CharacterBody3D
## The AI prey the monster hunts in solo tests (spec S-004, Q4): a PreyBrain
## decides, this body moves on the navigation mesh at the hunted's speeds and
## makes the hunted's footstep noises (FootstepEmitter). It hears the monster
## through NoiseBus and sees it within its sight range. Out of breath after a
## run, it pants faintly (only the scan reveals it). When a building it is in
## is scanned, it notices the flickering lights one time out of two and
## freezes until the scan ends (Q5).
## In the game loop (S-007, Q7) it looks for the fuses, repairs the transformer
## and runs for the exit, holding "interact" like the hunted (HoldInteraction).

signal state_changed(state: PreyBrain.State)
## It used a ruse (S-008): "bottle", "decoy", "hide", "car_alarm" or "firecracker".
signal ruse_used(kind: StringName)

## Every AI prey, so a teammate's "monstre ici" mark reaches it (S-020, T-328).
const GROUP := &"preys"
## Distance the target must move before the path is recomputed, in meters.
const RETARGET_DISTANCE := 0.5
const DOOR_SETTINGS := preload("res://game/data/door_settings.tres")
const BOTTLE_SCENE := preload("res://game/entities/bottle/thrown_bottle.tscn")
const DECOY_SCENE := preload("res://game/entities/decoy/decoy.tscn")
const FIRECRACKER_SCENE := preload("res://game/entities/firecracker/firecracker.tscn")
## Length of the gestures its body shows (S-011, T-125).
const BODY_SETTINGS := preload("res://game/data/hunted_body_settings.tres")

@export var settings: PreySettings
## Speeds of the hunted (S-001).
@export var motion: PlayerSettings
## Node whose Marker3D children are the points the prey wanders between.
@export var wander_route: Node3D
## Node whose Marker3D children are the hiding spots.
@export var hiding_spots: Node3D
## Values of the ruses it uses like the hunted (S-008).
@export var ruse_settings: RuseSettings
## The playable monster, with get_eye_position().
@export var monster: Node3D
## Buildings whose scans the prey may notice.
@export var buildings: Array[Building] = []

var brain: PreyBrain
var sees_monster := false
## The game it plays (S-007), null outside the game loop.
var game_loop: GameLoop
## The objectives besides fuses (S-018, T-268).
var tasks: PreyTasks
## What it carries (S-008, Q9).
var inventory: Inventory
## The hiding spot it is in, or null.
var hiding_in: HidingSpot
## How many times it used each ruse, by kind (S-008).
var ruse_counts := {}
## Online room (S-010, T-101): its capture rule, null otherwise.
var capture: CaptureState
## Captured, on its knees (T-107): it neither moves nor acts.
var held := false:
	set = set_held
## What its hands do, as its body and the players see it (S-011, T-125).
var gesture := BodyGesture.new()

## Getting over a window or a low wall on its way (S-020, T-340).
var vault_motion := VaultMotion.new()

var _heard_monster := false
var _vision_timer := 0.0
var _stuck_left := 0.0
var _jamb := JambUnstick.new()
var _breath_timer := 0.0
## Game loop (S-007): the boxes in visiting order, and what it holds on.
var _boxes: Array[FuseBox] = []
var _hold := HoldInteraction.new()
## Building whose scan the prey noticed, or null.
var _warned_by: Building
## S-008: the pickup it is going for, the hiding spot it flees to or hides
## in, the alarm clock it placed, and its own hold on the hiding spot.
var _detour: Pickup
var _hide_spot: HidingSpot
var _decoy: Decoy
var _hide_hold := HoldInteraction.new()
var _pickup_look_left := 0.0
var _hide_look_left := 0.0
## A car alarm it swerves to while it flees, and where it was fleeing to.
var _car_detour: CarAlarm
var _flee_target := Vector3.ZERO
var _was_fleeing := false
## The last door it opened on its way (S-016), to close behind it in flight.
var _opened_door: Door
var _rng := RandomNumberGenerator.new()
## Online (T-101): a captured teammate it goes to free (its CaptureState), or
## a dropped fuse it goes to take, and where it stands for it.
var _errand: Node3D
var _errand_spot := Vector3.ZERO
var _errand_look_left := 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body: HuntedBody = $Body


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = hash(name)
	inventory = Inventory.new(ruse_settings)
	brain = PreyBrain.new(settings, _rng.randi())
	brain.state_changed.connect(state_changed.emit)
	brain.set_points(markers_of(wander_route), markers_of(hiding_spots))
	_agent.target_position = brain.target
	Vault.use_links(_agent, false)
	# A full stuck timer from the start: at 0 it gave up its first goal on its
	# first frame, before the navigation had its first path.
	_stuck_left = settings.stuck_time
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	for building in buildings:
		building.scan_changed.connect(_on_scan_changed.bind(building))


static func markers_of(parent: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if parent == null:
		return points
	for child in parent.get_children():
		if child is Node3D:
			points.append(child.global_position)
	return points


## Plays the game loop: visits the buildings one by one, nearest first, and the
## boxes of each building nearest first (S-007, Q7). A seed other than 0 makes
## its choices differ from one game to the next.
func start_loop(loop: GameLoop, boxes: Array[FuseBox], rng_seed := 0) -> void:
	game_loop = loop
	if rng_seed != 0:
		_rng.seed = rng_seed
		brain.reseed(_rng.randi())
	_boxes = order_boxes(boxes, global_position)
	var slots: Array[Vector3] = []
	for box in _boxes:
		slots.append(box.get_approach_point())
	var transformer := loop.transformer
	var side := transformer.global_basis.z * (transformer.half_size.y + 0.8)
	var exit := loop.exit_zone.global_position
	exit.y = global_position.y
	brain.set_loop(slots, transformer.global_position + side, exit)
	tasks = PreyTasks.new(self, loop.quests)
	_agent.target_position = brain.target


## Visiting order: the nearest building first, then the nearest one from there;
## inside a building, the nearest box from the last one.
static func order_boxes(boxes: Array[FuseBox], from: Vector3) -> Array[FuseBox]:
	var by_building := {}
	for box in boxes:
		if not by_building.has(box.building_name):
			by_building[box.building_name] = []
		by_building[box.building_name].append(box)
	var ordered: Array[FuseBox] = []
	var at := from
	while not by_building.is_empty():
		var best_name := ""
		var best := INF
		for building_name: String in by_building:
			for box: FuseBox in by_building[building_name]:
				var distance := at.distance_to(box.global_position)
				if distance < best:
					best = distance
					best_name = building_name
		var left: Array = by_building[best_name]
		by_building.erase(best_name)
		while not left.is_empty():
			var nearest := 0
			for i in left.size():
				if (
					at.distance_to(left[i].global_position)
					< at.distance_to(left[nearest].global_position)
				):
					nearest = i
			var box: FuseBox = left.pop_at(nearest)
			ordered.append(box)
			at = box.global_position
	return ordered


func get_state() -> PreyBrain.State:
	return brain.state


func get_gait() -> PlayerMotion.Gait:
	return PlayerMotion.Gait.CROUCH if held else brain.get_gait()


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * settings.ear_height


func _process(_delta: float) -> void:
	var down := held or (capture != null and capture.state == CaptureState.State.CAPTURED)
	_body.show_state(get_gait(), Vector2(velocity.x, velocity.z).length(), down, get_gesture())


## What its hands do: working while it holds "interact" on something (a fuse
## box, a hiding spot, a teammate), else its last gesture, for its length.
func get_gesture() -> HuntedBody.Gesture:
	if _hold.holding or _hide_hold.holding:
		return HuntedBody.Gesture.WORK
	return gesture.kind as HuntedBody.Gesture


func _physics_process(delta: float) -> void:
	gesture.update(delta)
	if held:
		_stay_down(delta)
		return
	if vault_motion.is_active():
		global_position = vault_motion.step(delta)  # Over a wall (T-340).
		velocity = Vector3.ZERO
		_stuck_left = settings.stuck_time
		return
	var threat := Vector3.ZERO
	if monster != null:
		threat = monster.global_position
		_update_sight(delta)
	var alarm := sees_monster or _heard_monster
	_heard_monster = false
	var arrived := _agent.is_navigation_finished()
	brain.update(delta, alarm, threat, arrived, is_warned())
	_use_ruses(delta, threat)
	if game_loop != null:
		_play_loop(delta, arrived)
	if _agent.target_position.distance_to(brain.target) > RETARGET_DISTANCE:
		_agent.target_position = brain.target
		_stuck_left = settings.stuck_time
	_pant(delta)
	_show_if_revealed()
	if _update_hiding(delta):
		return  # Inside a hiding spot, or getting out of it: no move.
	if _errand != null and _hold.holding:
		velocity = Vector3.ZERO  # Freeing a teammate or taking a fuse: it stays.
		_stuck_left = settings.stuck_time
		return
	var before := global_position
	_move(delta)
	_check_stuck(delta, before)


## The loop's part of a frame: decides at a box or the transformer, and holds
## "interact" while it works.
func _play_loop(delta: float, arrived: bool) -> void:
	var work_on: Node = null
	match brain.state:
		PreyBrain.State.SEARCH:
			if _errand != null:
				work_on = _errand if _errand.can_interact(global_position) else null
			elif (
				_detour == null
				and arrived
				and _agent.target_position.distance_to(brain.target) <= RETARGET_DISTANCE
			):
				_arrive()
		PreyBrain.State.WORK:
			work_on = _work_target()
	if brain.state != PreyBrain.State.WORK and tasks != null:
		tasks.drop()  # Fled from a terminal: up first.
	_hold.update(self, work_on, work_on != null, delta)
	if brain.goal == PreyBrain.Goal.TASK and brain.state == PreyBrain.State.WORK:
		if tasks.work(delta):
			next_goal()
	elif brain.state == PreyBrain.State.WORK and _work_finished():
		next_goal()


## After a piece of work (S-018, T-268): the exit once repaired, the fuses
## still to find, the transformer with what it carries, the other
## objectives, else the transformer to wait there as before.
func next_goal() -> void:
	var rules := game_loop.rules
	var carries := game_loop.carried_by(self) > 0
	if game_loop.quests != null and game_loop.quests.carries_disk(self):
		carries = true
	if rules.is_repaired():
		brain.go_for(PreyBrain.Goal.EXIT)
	elif rules.found() < rules.fuse_count:
		brain.work_done(rules.found(), rules.fuse_count, false)
	elif carries:
		brain.go_for(PreyBrain.Goal.REPAIR)
	elif tasks != null and tasks.choose() != PreyTasks.Kind.NONE:
		brain.go_task(tasks.point(), tasks.is_rush())
	else:
		brain.go_for(PreyBrain.Goal.REPAIR)


## It reached the slot or the transformer it was heading to.
func _arrive() -> void:
	if brain.goal == PreyBrain.Goal.TASK:
		if tasks.arrive():
			brain.start_work()
		else:
			next_goal()
		return
	if brain.goal == PreyBrain.Goal.REPAIR:
		if _decoy != null and is_instance_valid(_decoy):
			if _decoy.timer.state == DecoyTimer.State.TICKING:
				return  # Waits for its alarm clock to draw the monster away (Q9).
		brain.start_work()
	elif _boxes[brain.slot_index].has_fuse:
		brain.start_work()  # It sees the red LED.
	elif game_loop.rules.found() >= game_loop.rules.fuse_count:
		next_goal()  # Teammates found the rest (S-010, T-100).
	else:
		brain.next_slot()


func _work_target() -> Node:
	if brain.goal == PreyBrain.Goal.TASK:
		return tasks.work_target()
	if brain.goal == PreyBrain.Goal.REPAIR:
		return game_loop.transformer
	return _boxes[brain.slot_index]


func _work_finished() -> bool:
	if brain.goal == PreyBrain.Goal.REPAIR:
		var disk := game_loop.quests != null and game_loop.quests.carries_disk(self)
		return (game_loop.carried_by(self) == 0 and not disk) or game_loop.rules.is_repaired()
	return not _boxes[brain.slot_index].has_fuse


## The ruses of S-008 (Q9), each a simple rule: take what lies close on its
## way, throw a bottle away from its goal and hide or set off an alarm when it
## flees, place an alarm clock before repairing.
func _use_ruses(delta: float, threat: Vector3) -> void:
	var fleeing := brain.state == PreyBrain.State.FLEE
	if fleeing and not _was_fleeing:
		_on_flee_started(threat)
	_was_fleeing = fleeing
	_close_door_behind(fleeing)
	if fleeing:
		_set_off_car_alarms()
		_use_hospital_decoys(threat)
		_maybe_drop_firecracker(threat)
		_look_for_hiding_spot(delta, threat)
	else:
		_car_detour = null
	if _errand == null:
		_update_detour(delta)
	if _detour == null:
		_update_errand(delta)
	_maybe_place_decoy()


## In flight, it closes the door it just went through, if the monster does
## not see it: the closed door cuts the monster's sight (S-016, plan).
func _close_door_behind(fleeing: bool) -> void:
	if _opened_door == null or not is_instance_valid(_opened_door):
		_opened_door = null
		return
	var gap := _opened_door.global_position - global_position
	var past := Vector2(gap.x, gap.z).length() >= DOOR_SETTINGS.close_behind_distance
	if not past:
		return
	var heading := -global_basis.z
	var behind := Vector2(heading.x, heading.z).dot(Vector2(gap.x, gap.z)) < 0.0
	if fleeing and behind and _opened_door.is_open and not sees_monster:
		_opened_door.toggle(self, DOOR_SETTINGS.open_range)
	_opened_door = null  # Once past it, it forgets it either way.


func _on_flee_started(threat: Vector3) -> void:
	_detour = null
	if monster != null and global_position.distance_to(threat) >= settings.throw_safe_distance:
		throw_bottle_away()
	var spot := pick_hiding_spot(threat)
	if spot != null:
		_hide_spot = spot
		brain.flee_to(spot.get_exit_point())


## Keeps looking for a hiding spot along the way while it flees (Q9): one
## may come within reach after the start, once the monster is far enough.
func _look_for_hiding_spot(delta: float, threat: Vector3) -> void:
	_hide_look_left -= delta
	if _hide_spot != null or hiding_in != null or _hide_look_left > 0.0:
		return
	_hide_look_left = settings.pickup_look_interval
	if global_position.distance_to(threat) < settings.hide_flee_distance:
		return  # Too close behind: it would be caught at the door.
	var hunter: MonsterBrain = monster.get("brain") if monster != null else null
	if hunter != null and hunter.state == MonsterBrain.State.CHASE:
		return  # Hunted down: it would be seen getting in.
	var spot := pick_hiding_spot(threat)
	if spot != null:
		_hide_spot = spot
		_car_detour = null
		brain.flee_to(spot.get_exit_point())


## A free hiding spot close by that the monster cannot see, or null.
func pick_hiding_spot(_threat: Vector3) -> HidingSpot:
	var best: HidingSpot = null
	var best_distance := settings.hide_search_radius
	for node in get_tree().get_nodes_in_group(HidingSpot.GROUP):
		var spot := node as HidingSpot
		if not spot.is_free():
			continue
		var distance := global_position.distance_to(spot.get_exit_point())
		if distance > best_distance:
			continue
		if monster != null:
			var eye: Vector3 = monster.get_eye_position()
			var at := spot.get_exit_point() + Vector3.UP
			if (
				eye.distance_to(at) <= settings.sight_range
				and MonsterVision.has_line_of_sight(get_world_3d().direct_space_state, eye, at)
			):
				continue  # The monster would see it get in.
		best = spot
		best_distance = distance
	return best


## Throws a bottle 12 to 18 m away, opposite to where it is going (Q9).
func throw_bottle_away() -> ThrownBottle:
	if hiding_in != null or inventory.count(Inventory.Kind.BOTTLE) == 0:
		return null
	var away := global_position - brain.get_goal_point()
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = global_basis.z
	var distance := _rng.randf_range(settings.throw_distance_min, settings.throw_distance_max)
	return throw_bottle_to(global_position + away.normalized() * distance)


## Throws a bottle so that it lands at this point on flat ground.
func throw_bottle_to(point: Vector3) -> ThrownBottle:
	if hiding_in != null or not inventory.use(Inventory.Kind.BOTTLE):
		return null
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	var direction := flat.normalized() if flat.length_squared() > 0.0001 else -global_basis.z
	var lift := deg_to_rad(ruse_settings.throw_lift)
	var axis := direction.cross(Vector3.UP).normalized()
	var launch := direction.rotated(axis, lift)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var speed := ThrownBottle.speed_for_range(
		flat.length(),
		ruse_settings.throw_lift,
		settings.ear_height,
		gravity,
		ruse_settings.throw_speed
	)
	var bottle: ThrownBottle = BOTTLE_SCENE.instantiate()
	get_parent().add_child(bottle)
	bottle.global_position = get_eye_position() + direction * ruse_settings.throw_hand_offset
	bottle.linear_velocity = launch * speed
	NoiseBus.emit_noise(NoiseEvent.Type.THROW, global_position, ruse_settings.gesture_range, self)
	gesture.play(HuntedBody.Gesture.THROW, BODY_SETTINGS.throw_time)
	_count_ruse(&"bottle")
	return bottle


## Places an alarm clock where it stands (Q9).
func place_decoy() -> Decoy:
	if hiding_in != null or not inventory.use(Inventory.Kind.DECOY):
		return null
	var decoy: Decoy = DECOY_SCENE.instantiate()
	get_parent().add_child(decoy)
	decoy.global_position = global_position
	NoiseBus.emit_noise(NoiseEvent.Type.THROW, global_position, ruse_settings.gesture_range, self)
	gesture.play(HuntedBody.Gesture.PICK, BODY_SETTINGS.pick_time)
	_count_ruse(&"decoy")
	_decoy = decoy
	return decoy


## Fleeing, the monster close behind, it drops its firecracker at its feet
## (S-020, T-312): the monster on its trail sets it off.
func _maybe_drop_firecracker(threat: Vector3) -> void:
	if (
		hiding_in != null
		or global_position.distance_to(threat) > settings.firecracker_drop_distance
		or not inventory.use(Inventory.Kind.FIRECRACKER)
	):
		return
	var firecracker: Firecracker = FIRECRACKER_SCENE.instantiate()
	get_parent().add_child(firecracker)
	firecracker.global_position = global_position
	gesture.play(HuntedBody.Gesture.PICK, BODY_SETTINGS.pick_time)
	_count_ruse(&"firecracker")


## On its way to repair, between 30 and 20 m from the transformer, it places
## its alarm clock (Q9).
func _maybe_place_decoy() -> void:
	if (
		game_loop == null
		or _decoy != null
		or brain.state != PreyBrain.State.SEARCH
		or brain.goal != PreyBrain.Goal.REPAIR
		or inventory.count(Inventory.Kind.DECOY) == 0
	):
		return
	var distance := global_position.distance_to(brain.get_goal_point())
	if distance <= settings.decoy_trigger_distance and distance >= settings.decoy_min_distance:
		place_decoy()


## Fleeing past a car whose alarm can ring, it sets it off (Q9).
func _set_off_car_alarms() -> void:
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var car := node as CarAlarm
		if car != null and car.can_interact(global_position):
			car.interact(self)
			_count_ruse(&"car_alarm")
	if _car_detour != null and _car_detour.state != CarAlarm.State.IDLE:
		_car_detour = null  # Set off: on to where it was fleeing.
		brain.flee_to(_flee_target)
	if _car_detour == null and _hide_spot == null:
		_swerve_to_car_alarm()


## Fleeing in the hospital (S-014, T-192), like a car alarm in the street: it
## switches on a monitor it passes, and sends a wheelchair rolling off to the
## side, away from where it runs, so the noise draws the monster aside.
func _use_hospital_decoys(threat: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(Monitor.GROUP):
		var monitor := node as Monitor
		if monitor.wanted_by(self) and monitor.can_interact(global_position):
			monitor.interact(self)
			_count_ruse(&"monitor")
	var away := global_position - threat
	away.y = 0.0
	var side := Vector3(-away.z, 0.0, away.x).normalized()
	for node in get_tree().get_nodes_in_group(Wheelchair.GROUP):
		var chair := node as Wheelchair
		if chair.wanted_by(self) and chair.can_interact(global_position):
			# Pushed sideways, away from the hunted.
			var to_chair := chair.global_position - global_position
			chair.launch(side if side.dot(to_chair) >= 0.0 else -side)
			_count_ruse(&"wheelchair")
			return


## A resting car alarm a few steps off its way: it swerves to set it off in
## passing (Q9), the din covering its run.
func _swerve_to_car_alarm() -> void:
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var car := node as CarAlarm
		if (
			car != null
			and car.state == CarAlarm.State.IDLE
			and global_position.distance_to(car.global_position) <= settings.car_alarm_detour
		):
			_car_detour = car
			_flee_target = brain.target
			brain.flee_to(car.global_position)
			return


## Takes what lies close to its way while it searches calmly (Q9).
func _update_detour(delta: float) -> void:
	if _detour != null:
		if (
			not is_instance_valid(_detour)
			or _detour.is_queued_for_deletion()
			or brain.state != PreyBrain.State.SEARCH
			or brain.target.distance_to(_detour.global_position) > RETARGET_DISTANCE
		):
			_end_detour()
		elif _detour.can_interact(global_position):
			gesture.play(HuntedBody.Gesture.PICK, BODY_SETTINGS.pick_time)
			_detour.interact(self)
			_end_detour()
		return
	_pickup_look_left -= delta
	if _pickup_look_left > 0.0 or brain.state != PreyBrain.State.SEARCH:
		return
	_pickup_look_left = settings.pickup_look_interval
	var best: Pickup = null
	var best_distance := settings.pickup_detour
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var pickup := node as Pickup
		if pickup == null or pickup.is_queued_for_deletion() or not pickup.wanted_by(self):
			continue
		var distance := global_position.distance_to(pickup.global_position)
		if distance <= best_distance:
			best = pickup
			best_distance = distance
	if best != null and brain.detour_to(best.global_position):
		_detour = best


func _end_detour() -> void:
	var had := _detour != null
	_detour = null
	if had:
		brain.end_detour()


## Online (S-010, T-101): while it searches calmly and no pickup draws it,
## it goes to free a captured teammate, or to take a fuse a captured hunted
## dropped while fuses are still missing; only while the monster is far from
## there. Rescue first: a free teammate counts more than a fuse.
func _update_errand(delta: float) -> void:
	if _errand != null:
		if (
			not _errand_wanted(_errand)
			or brain.state != PreyBrain.State.SEARCH
			or brain.target.distance_to(_errand_spot) > RETARGET_DISTANCE
		):
			_end_errand()
		return
	_errand_look_left -= delta
	if game_loop == null or _errand_look_left > 0.0 or brain.state != PreyBrain.State.SEARCH:
		return
	_errand_look_left = settings.pickup_look_interval
	var best: Node3D = null
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var captured := node as CaptureState
		if (
			captured != null
			and _errand_wanted(captured)
			and global_position.distance_to(captured.global_position) <= settings.rescue_detour
			and (best == null or _closer(captured, best))
		):
			best = captured
	if best == null and game_loop.rules.found() < game_loop.rules.fuse_count:
		for drop in game_loop.drops:
			if (
				_errand_wanted(drop)
				and global_position.distance_to(drop.global_position) <= settings.drop_detour
				and (best == null or _closer(drop, best))
			):
				best = drop
	if best == null:
		return
	var spot := best.global_position
	if best is CaptureState and (best as CaptureState).get_cage() != null:
		spot = (best as CaptureState).rescue_point()  # Before its cage's grille (S-018).
	elif best is CaptureState:  # Beside it, not into its body.
		var side := global_position - spot
		side.y = 0.0
		spot += side.normalized() * 0.8 if side.length_squared() > 0.01 else Vector3.ZERO
	if brain.detour_to(spot):
		_errand = best
		_errand_spot = spot


## Whether an errand is still worth it: still there, and the monster far.
func _errand_wanted(node: Node3D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if node is CaptureState:
		var captured := node as CaptureState
		if captured.state != CaptureState.State.CAPTURED or not captured.wanted_by(self):
			return false
		if captured.prison != null and captured.get_cage() == null:
			return false  # On its way to a cage (S-018): nothing to open yet.
	elif not (node as FuseBox).has_fuse:
		return false
	return (
		monster == null
		or (
			monster.global_position.distance_to(node.global_position)
			>= settings.rescue_safe_distance
		)
	)


func _closer(a: Node3D, b: Node3D) -> bool:
	return (
		global_position.distance_squared_to(a.global_position)
		< global_position.distance_squared_to(b.global_position)
	)


func _end_errand() -> void:
	_errand = null
	if brain.state != PreyBrain.State.SEARCH:
		return  # Fled: the brain already left it.
	if game_loop != null:
		var rules := game_loop.rules
		if brain.goal == PreyBrain.Goal.FUSES and rules.found() >= rules.fuse_count:
			brain.goal = PreyBrain.Goal.REPAIR  # It took the last one.
	brain.end_detour()


## Online (T-107): captured or freed. Captured, it drops what it was doing.
func set_held(value: bool) -> void:
	held = value
	if not held:
		return
	if hiding_in != null:
		hiding_in.occupant = null
		leave_hiding()
	_hide_spot = null
	_detour = null
	_errand = null
	_car_detour = null


## Captured: on its knees where it is, still falling if in the air.
func _stay_down(delta: float) -> void:
	_hold.update(self, null, false, delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()


## Gets into the hiding spot it fled to, stays while it hides, and gets out
## when it goes back to its goal, holding "interact" each time like the hunted.
## Returns true while it must not move.
func _update_hiding(delta: float) -> bool:
	if hiding_in != null and _hide_spot == null:
		_hide_spot = hiding_in
	if _hide_spot == null:
		return false
	var hiding := brain.state == PreyBrain.State.HIDE
	var want := false
	if hiding and hiding_in == null:
		if not _hide_spot.wanted_by(self):
			_hide_spot = null  # Taken meanwhile: it hides crouched where it is.
			return false
		want = _hide_spot.can_interact(global_position)
	elif not hiding and brain.state != PreyBrain.State.FLEE and hiding_in != null:
		want = true  # Back to its goal: out first.
	elif not hiding and brain.state != PreyBrain.State.FLEE and hiding_in == null:
		_hide_hold.update(self, null, false, delta)
		_hide_spot = null
		return false
	_hide_hold.update(self, _hide_spot, want, delta)
	return hiding_in != null or want


## Gets into a hiding spot (S-008): still, out of reach, out of sight.
func hide_in(spot: HidingSpot) -> void:
	hiding_in = spot
	velocity = Vector3.ZERO
	$CollisionShape3D.disabled = true
	$Body.visible = false
	global_position = spot.global_position
	_count_ruse(&"hide")


func leave_hiding() -> void:
	if hiding_in == null:
		return
	global_position = hiding_in.get_exit_point()
	hiding_in = null
	$CollisionShape3D.disabled = false
	$Body.visible = true
	velocity = Vector3.ZERO


func is_hidden() -> bool:
	return hiding_in != null


## Behind a curtain or boxes, the body shows to a monster close by that looks
## at it (S-016, Q6): the playable monster sees it, and may open the spot.
func _show_if_revealed() -> void:
	if hiding_in == null or hiding_in.family != HidingSpot.Family.MAKESHIFT or monster == null:
		return
	$Body.visible = HidingSpot.is_revealed(
		self, monster.get_ear_position(), -monster.global_basis.z
	)


func _count_ruse(kind: StringName) -> void:
	ruse_counts[kind] = ruse_counts.get(kind, 0) + 1
	ruse_used.emit(kind)


## True while the prey noticed a scan and the scan is still on.
func is_warned() -> bool:
	return _warned_by != null


## Back to wandering from a wander point, rested (after a catch).
func respawn(at: Vector3, index: int) -> void:
	if hiding_in != null:
		hiding_in.occupant = null
		leave_hiding()
	_hide_spot = null
	_detour = null
	global_position = at
	velocity = Vector3.ZERO
	_warned_by = null
	_breath_timer = 0.0
	brain.reset(index)
	_agent.target_position = brain.target


## The faint panting of an out of breath prey, at its mouth.
func _pant(delta: float) -> void:
	if not brain.is_breathless():
		_breath_timer = 0.0
		return
	_breath_timer += delta
	if _breath_timer >= settings.breath_interval:
		_breath_timer = 0.0
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, get_eye_position(), settings.breath_range, self)


func _on_scan_changed(is_scanned: bool, building: Building) -> void:
	if not is_scanned:
		if building == _warned_by:
			_warned_by = null
		return
	if building.contains(get_eye_position()) and _rng.randf() < settings.scan_notice_chance:
		_warned_by = building


## Gives up a target it cannot reach: blocked against a wall, or off the mesh.
func _check_stuck(delta: float, before: Vector3) -> void:
	var trying := not brain.is_still(_agent.is_navigation_finished())
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var expected := PlayerMotion.speed_for_gait(motion, brain.get_gait()) * delta
	if not trying or moved > expected * 0.25:
		_stuck_left = settings.stuck_time
		return
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		_stuck_left = settings.stuck_time
		brain.give_up()


func _update_sight(delta: float) -> void:
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer = settings.vision_interval
	sees_monster = can_see_monster()


## Whether the monster is in the prey's field of view, in range, and not behind a wall.
func can_see_monster() -> bool:
	var eye := get_eye_position()
	var target: Vector3 = monster.get_eye_position()
	var to_target := target - eye
	if to_target.length() > settings.sight_range:
		return false
	var forward := -global_basis.z
	var angle := rad_to_deg(
		Vector3(forward.x, 0.0, forward.z).angle_to(Vector3(to_target.x, 0.0, to_target.z))
	)
	return (
		angle <= settings.vision_angle / 2.0
		and MonsterVision.has_line_of_sight(get_world_3d().direct_space_state, eye, target)
	)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.source == self or event.source != monster:
		return
	if NoiseBus.can_hear(event, get_eye_position()):
		_heard_monster = true


## A teammate marked the monster at "at" (S-020, T-328): within flee_range, the
## prey takes it as hearing the monster, so it runs away and hides.
func warn_of_monster(at: Vector3, flee_range: float) -> void:
	if global_position.distance_to(at) <= flee_range:
		_heard_monster = true


func _move(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if not brain.is_still(_agent.is_navigation_finished()) and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var direction := next - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
			horizontal = direction * PlayerMotion.speed_for_gait(motion, brain.get_gait())
			look_at(global_position + direction, Vector3.UP)
			# A closed door on its way: it opens it, standing (S-016).
			var door := Door.closed_ahead(
				get_tree(), global_position, direction, DOOR_SETTINGS.ai_reach
			)
			if door != null:
				door.open_by(self)
				_opened_door = door
			var vault := Vault.across(get_tree(), global_position, next)
			if vault != null and vault.climb(self):
				return  # Climbing from the next frame (T-340).
	if global_position.distance_to(_agent.target_position) > JambUnstick.GOAL_CLEARANCE:
		horizontal = _jamb.update(self, horizontal, delta)  # Not at its goal: a jamb.
		if _jamb.take_replan():
			_agent.target_position = _agent.target_position  # Plans its path again.
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
