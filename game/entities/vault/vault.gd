class_name Vault
extends Node3D
## A window or a low wall one can climb over (spec S-020, T-340, piste E6).
## The wall itself is built by the map; this node only marks the passage: its
## X axis runs along the wall, the wall is `thickness` thick around its
## origin, and its top is `top` meters above the origin.
##
## The hunted presses "interact" in front of it and lands on the other side
## after hunted_time (0.5 s); a monster takes monster_time (1.5 s). Both make a
## noise. Crouched, hidden or at a terminal, nobody climbs. A body climbs if
## it has a `vault_motion` (VaultMotion): the player, the monster avatar.
## The hunted presses "interact" (interact()); the monster, which only holds
## "interact" on things, holds it (hold()). Holding on after landing does not
## climb back: the key must be let go first.
##
## The AIs (monster.gd, prey.gd) take it through two navigation links across
## the wall, one per side of the hunt (MONSTER_LAYER, HUNTED_LAYER), each at
## the cost of its climbing time: an agent whose navigation layers include
## the layer plans paths over the wall, and climbs when its next path point
## lies across it (across()).

## Someone got over it, from one side to the other.
signal climbed(by: Node3D)

## The passages of the map, for the AIs.
const GROUP := &"vaults"
## Navigation layers of the links: the monster's, the hunted's. The map's
## mesh is on layer 1; the AI agents add theirs (use_links()).
const MONSTER_LAYER := 2
const HUNTED_LAYER := 3

@export var settings: VaultSettings
## Width of the passage along the wall, in meters.
@export var width := 1.2
## Height of the top of the wall or of the sill above the origin, in meters.
@export var top := 0.9
## Thickness of the wall, in meters.
@export var thickness := 0.3

## Bodies that climbed with the key still held: they wait for its release.
var _waiting := {}


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	add_to_group(GROUP)
	_add_link(MONSTER_LAYER, settings.monster_link_cost)
	_add_link(HUNTED_LAYER, settings.hunted_link_cost)


## A two-way link across the wall, from landing point to landing point.
func _add_link(layer: int, cost: float) -> void:
	var link := NavigationLink3D.new()
	link.name = "Link%d" % layer
	link.navigation_layers = 1 << (layer - 1)
	link.enter_cost = cost
	var away := thickness / 2.0 + settings.landing_distance
	link.start_position = Vector3(0, 0, -away)
	link.end_position = Vector3(0, 0, away)
	add_child(link)


## Lets an AI agent plan its paths over the passages: the monster's links if
## `monster`, the hunted's otherwise.
static func use_links(agent: NavigationAgent3D, monster: bool) -> void:
	agent.set_navigation_layer_value(MONSTER_LAYER if monster else HUNTED_LAYER, true)


## The passage an AI at `at` must climb to reach its next path point `next`:
## within reach, with `next` across its wall. Null when there is none.
static func across(tree: SceneTree, at: Vector3, next: Vector3) -> Vault:
	for node in tree.get_nodes_in_group(GROUP):
		var vault := node as Vault
		if vault == null or not vault.can_interact(at):
			continue
		var here := vault.to_local(at)
		var there := vault.to_local(next)
		if here.z * there.z < 0.0 and absf(there.x) <= vault.width / 2.0 + 1.0:
			return vault
	return null


## The point of the passage nearest to a position, on the wall's line.
func closest_point(at: Vector3) -> Vector3:
	var local := to_local(at)
	return to_global(Vector3(clampf(local.x, -width / 2.0, width / 2.0), 0.0, 0.0))


func can_interact(from: Vector3) -> bool:
	var gap := from - closest_point(from)
	return Vector2(gap.x, gap.z).length() <= settings.reach and absf(gap.y) <= settings.reach


## Only standing (not sneaking) bodies climb.
func wanted_by(user: Node) -> bool:
	return not (user.has_method("is_sneaking") and user.is_sneaking())


func get_prompt() -> String:
	return "HUD_INTERACT_VAULT"


## Where a body standing at `from` lands: across the wall, facing away from
## where it stood, landing_distance past the far face.
func landing_for(from: Vector3) -> Vector3:
	var local := to_local(from)
	var side := -1.0 if local.z >= 0.0 else 1.0
	var x := clampf(local.x, -width / 2.0 + 0.2, width / 2.0 - 0.2) if width > 0.4 else 0.0
	var landing := Vector3(x, 0.0, side * (thickness / 2.0 + settings.landing_distance))
	return to_global(landing)


## The time a body takes to get over: the hunted's or the monster's.
func time_for(user: Node) -> float:
	return settings.monster_time if is_monster(user) else settings.hunted_time


static func is_monster(user: Node) -> bool:
	return user != null and user.is_in_group(Prison.MONSTERS_GROUP)


## Makes the user get over, if it can climb and wants to. Returns whether
## it started.
func climb(user: Node) -> bool:
	var motion: VaultMotion = user.get("vault_motion") if user != null else null
	if motion == null or motion.is_active() or not user is Node3D or not wanted_by(user):
		return false
	var body := user as Node3D
	var from := body.global_position
	var land := landing_for(from)
	land.y = from.y  # Same floor on both sides.
	var height := global_position.y + top + settings.clearance
	motion.start(from, land, time_for(user), height)
	var noise := settings.monster_range if is_monster(user) else settings.hunted_range
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, closest_point(from), noise, user)
	climbed.emit(body)
	return true


func interact(user: Node) -> void:
	climb(user)


## One frame of holding "interact" (HoldInteraction): climbs once per press.
func hold(user: Node, _delta: float) -> bool:
	if _waiting.has(user):
		return false
	_waiting[user] = true
	return climb(user)


func release(user: Node) -> void:
	_waiting.erase(user)


func get_hold_ratio() -> float:
	return 0.0
