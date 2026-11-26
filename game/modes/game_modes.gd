class_name GameModes
extends RefCounted
## The list of game modes (spec S-024, Q26, T-375): the Traque (the game as
## it was) and each mode module of game/modes/. The menus read it: "Jouer
## seul" shows a mode's entries if it is listed here, the leader of an online
## game picks among the modes that play online. A mode is a name kept in
## GameSession.mode; the map adds the mode's node when it starts.
## To add or remove a mode: docs/MODULES.md, "Un mode de jeu".

const HUNT := &"hunt"
const VERSUS := &"versus"

## Each mode: its name, the key of its name in strings.csv, and whether it
## plays online (the Versus does since T-381).
const LIST: Array[Dictionary] = [
	{"id": HUNT, "name_key": "MODE_HUNT", "online": true},
	{"id": VERSUS, "name_key": "MODE_VERSUS", "online": true},
]


## Whether mode is listed (a removed module is not).
static func has(mode: StringName) -> bool:
	return _find(mode) != {}


## The text key of a mode's name, for the menus.
static func name_key(mode: StringName) -> String:
	return str(_find(mode).get("name_key", "MODE_HUNT"))


## The modes an online game can play, in list order.
static func online() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in LIST:
		if entry["online"]:
			found.append(entry["id"])
	return found


## Whether an online game may play mode.
static func plays_online(mode: StringName) -> bool:
	return bool(_find(mode).get("online", false))


## The online mode after mode, back to the first after the last.
static func next_online(mode: StringName) -> StringName:
	var modes := online()
	var index := modes.find(mode)
	return modes[(index + 1) % modes.size()]


## A mode read from the network or a file: itself if known, else the Traque.
static func sanitize(mode: Variant) -> StringName:
	var wanted := StringName(str(mode))
	return wanted if has(wanted) else HUNT


static func _find(mode: StringName) -> Dictionary:
	for entry in LIST:
		if entry["id"] == mode:
			return entry
	return {}
