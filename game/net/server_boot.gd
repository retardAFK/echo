class_name ServerBoot
extends RefCounted
## How this process was started (S-010, T-094): the game, the lobby
## (`-- --lobby`) or one room (`-- --room <slot> --code <code>`).

enum Mode { GAME, LOBBY, ROOM }

const LOBBY_SCENE := "res://game/net/lobby_server.tscn"
const ROOM_SCENE := "res://game/net/room_server.tscn"

## Filled by parse(); read by the room scene.
static var mode := Mode.GAME
static var room_slot := 0
static var room_code := ""


## Reads the command line arguments given after "--". Returns false if they
## ask for a room without a valid slot and code.
static func parse(args: PackedStringArray) -> bool:
	mode = Mode.GAME
	if args.has("--lobby"):
		mode = Mode.LOBBY
		return true
	var at := args.find("--room")
	if at < 0:
		return true
	var code_at := args.find("--code")
	if at + 1 >= args.size() or code_at < 0 or code_at + 1 >= args.size():
		return false
	var slot := args[at + 1]
	if not slot.is_valid_int() or int(slot) < 1 or not RoomCode.is_valid(args[code_at + 1]):
		return false
	mode = Mode.ROOM
	room_slot = int(slot)
	room_code = args[code_at + 1]
	return true


## The scene this process runs instead of the menu, or "" for the game.
static func scene() -> String:
	match mode:
		Mode.LOBBY:
			return LOBBY_SCENE
		Mode.ROOM:
			return ROOM_SCENE
	return ""
