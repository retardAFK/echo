class_name ControlsText
extends RefCounted
## The controls and the goal of a role (spec S-009, Q5, T-080), shown after
## the role choice and in the pause menu. Translation keys, one line each.

const HUNTED_KEYS: Array[String] = [
	"CONTROLS_MOVE",
	"CONTROLS_LOOK",
	"CONTROLS_SPRINT",
	"CONTROLS_CROUCH",
	"CONTROLS_HOLD_BREATH",
	"CONTROLS_INTERACT",
	"CONTROLS_THROW",
	"CONTROLS_DECOY",
	"CONTROLS_FIRECRACKER",
	"CONTROLS_MAP",
	"CONTROLS_PAUSE",
]
const MONSTER_KEYS: Array[String] = [
	"CONTROLS_MOVE",
	"CONTROLS_LOOK",
	"CONTROLS_SPRINT",
	"CONTROLS_PROWL",
	"CONTROLS_SCAN",
	"CONTROLS_OPEN",
	"CONTROLS_PAUSE",
]


static func keys_for(role: GameSession.Role) -> Array[String]:
	return MONSTER_KEYS if role == GameSession.Role.MONSTER else HUNTED_KEYS


static func goal_key(role: GameSession.Role) -> String:
	return "GOAL_MONSTER" if role == GameSession.Role.MONSTER else "GOAL_HUNTED"


## The controls of a role, translated, one per line.
static func controls(role: GameSession.Role) -> String:
	var lines: Array[String] = []
	for key in keys_for(role):
		lines.append(Text.with_keys(key))
	return "\n".join(lines)
