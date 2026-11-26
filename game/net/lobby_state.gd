class_name LobbyState
extends RefCounted
## The waiting room of a game (S-010, Q6, T-096), kept by the room: four
## seats (the monster, then hunted 1 to 3), who sits where, who is ready, and
## the leader. A seat nobody sits in is played by an AI. Players are the
## numbers RoomLink gives them (1 to room_size). Pure, so tests need no network.
## The leader sets how many play (2 to 4: the monster and 1 to 3 hunted); the
## roles are drawn at random at launch, a player always the monster. The
## leader also picks the game mode among GameModes.online() (S-024, T-375).

const MONSTER_SEAT := 0
const SEATS := 4
const MIN_GAME_SIZE := 2

## Player in each seat, 0 for an AI.
var seats: Array[int] = [0, 0, 0, 0]
## The player who sets the game size and launches: the first one in, then
## the next.
var leader := 0
## Game code, shown in the waiting room.
var code := ""
var started := false
## How many humans may join, monster included. The game always has 3 hunted:
## the seats left free are played by AI preys (S-020, T-314).
var game_size := SEATS
## The game mode (S-024, Q26): GameModes.HUNT or a mode that plays online.
var mode := GameModes.HUNT
## The gadgets each player picked (S-023, Q3 and Q4, T-352): player ->
## indexes in the GadgetList (Loadout.to_indexes). Kept by the room only: the
## roles are drawn at launch, so a client that saw them could be the monster
## that knows who took the smoke (to_dict leaves them out unless asked).
var loadouts := {}
## Draws the roles at launch; tests seed it.
var rng := RandomNumberGenerator.new()

var _ready := {}


func _init() -> void:
	rng.randomize()


## A new player sits in the first free hunted seat, else the monster's.
## Returns false if every seat is taken or the game has started.
func add_player(player: int) -> bool:
	if started or seat_of(player) >= 0:
		return false
	var seat := _first_free_seat()
	if seat < 0 or players().size() >= game_size:
		return false
	seats[seat] = player
	_ready[player] = false
	if leader == 0:
		leader = player
	return true


func remove_player(player: int) -> void:
	var seat := seat_of(player)
	if seat >= 0:
		seats[seat] = 0
	_ready.erase(player)
	loadouts.erase(player)
	if leader == player:
		var others := players()
		others.sort()
		leader = others[0] if not others.is_empty() else 0


func set_ready(player: int, is_ready: bool) -> void:
	if not started and _ready.has(player):
		_ready[player] = is_ready


func is_ready(player: int) -> bool:
	return _ready.get(player, false)


## A player picks its gadgets (made valid), until the game starts.
func set_loadout(player: int, ids: Array) -> void:
	if not started and seat_of(player) >= 0:
		loadouts[player] = Loadout.to_indexes(Loadout.sanitize(ids))


## The gadgets a player picked, or the default ones.
func loadout_of(player: int) -> Array[StringName]:
	return Loadout.from_indexes(loadouts.get(player, Loadout.to_indexes(Loadout.default_ids())))


## The leader can launch when every player is ready.
func can_start(by: int) -> bool:
	if started or by != leader or by == 0:
		return false
	return players().all(is_ready)


## Launches the game and draws the roles at random.
func start(by: int) -> bool:
	if not can_start(by):
		return false
	deal()
	started = true
	return true


## The leader sets how many play, from MIN_GAME_SIZE to SEATS, never fewer
## than the players already in. Everyone is to say again they are ready.
func set_game_size(by: int, wanted: int) -> bool:
	if started or by != leader or by == 0:
		return false
	if wanted < MIN_GAME_SIZE or wanted > SEATS or wanted < players().size():
		return false
	game_size = wanted
	var present := players()
	for seat in SEATS:
		seats[seat] = 0
	for player in present:
		seats[_first_free_seat()] = player
		_ready[player] = false
	return true


## The leader picks the game mode, among those that play online (S-024,
## Q26). Everyone is to say again they are ready.
func set_mode(by: int, wanted: StringName) -> bool:
	if started or by != leader or by == 0 or not GameModes.plays_online(wanted):
		return false
	mode = wanted
	for player in players():
		_ready[player] = false
	return true


## Draws the roles: a player at random is the monster, the others the hunted
## seats from 1 on; the hunted seats left are played by AIs.
func deal() -> void:
	var present := players()
	for i in range(present.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept := present[i]
		present[i] = present[j]
		present[j] = kept
	for seat in SEATS:
		seats[seat] = 0
	for i in present.size():
		seats[i] = present[i]


## The game is over: back to waiting, everyone to say again they are ready.
func finish() -> void:
	started = false
	for player in _ready:
		_ready[player] = false


func seat_of(player: int) -> int:
	return seats.find(player) if player != 0 else -1


func players() -> Array[int]:
	var found: Array[int] = []
	for player in seats:
		if player != 0:
			found.append(player)
	return found


## The waiting room as sent to every client; with_loadouts only for the
## room's own map (S-023, Q4: the monster never learns the picks).
func to_dict(with_loadouts := false) -> Dictionary:
	var ready_players: Array[int] = []
	for player in players():
		if is_ready(player):
			ready_players.append(player)
	var picked := {}
	if with_loadouts:
		for player: int in loadouts:
			picked[str(player)] = loadouts[player]
	return {
		"loadouts": picked,
		"seats": seats.duplicate(),
		"leader": leader,
		"ready": ready_players,
		"code": code,
		"started": started,
		"game_size": game_size,
		"mode": String(mode),
	}


## What to_dict() wrote, read back by a client.
static func from_dict(data: Dictionary) -> LobbyState:
	var state := LobbyState.new()
	var seats_read: Array = data.get("seats", [])
	for i in mini(seats_read.size(), SEATS):
		state.seats[i] = int(seats_read[i])
	state.leader = int(data.get("leader", 0))
	state.code = str(data.get("code", ""))
	state.started = bool(data.get("started", false))
	state.game_size = clampi(int(data.get("game_size", SEATS)), MIN_GAME_SIZE, SEATS)
	state.mode = GameModes.sanitize(data.get("mode", GameModes.HUNT))
	var picked: Variant = data.get("loadouts", {})
	if picked is Dictionary:
		for player in state.players():
			var indexes: Variant = (picked as Dictionary).get(str(player))
			if indexes is Array:
				state.loadouts[player] = Loadout.to_indexes(Loadout.from_indexes(indexes))
	var ready_read: Array = data.get("ready", [])
	for player in state.players():
		state._ready[player] = ready_read.has(player) or ready_read.has(float(player))
	return state


func _first_free_seat() -> int:
	for seat in range(1, game_size):
		if seats[seat] == 0:
			return seat
	return MONSTER_SEAT if seats[MONSTER_SEAT] == 0 else -1
