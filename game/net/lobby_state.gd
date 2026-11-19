class_name LobbyState
extends RefCounted
## The waiting room of a game (S-010, Q6, T-096), kept by the room: four
## seats (the monster, then hunted 1 to 3), who sits where, who is ready, and
## the leader. A seat nobody sits in is played by an AI. Players are the
## numbers RoomLink gives them (1 to room_size). Pure, so tests need no network.
## The leader sets how many play (2 to 4: the monster and 1 to 3 hunted); the
## roles are drawn at random at launch, a player always the monster.

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
	if leader == player:
		var others := players()
		others.sort()
		leader = others[0] if not others.is_empty() else 0


func set_ready(player: int, is_ready: bool) -> void:
	if not started and _ready.has(player):
		_ready[player] = is_ready


func is_ready(player: int) -> bool:
	return _ready.get(player, false)


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


## The waiting room as sent to every client.
func to_dict() -> Dictionary:
	var ready_players: Array[int] = []
	for player in players():
		if is_ready(player):
			ready_players.append(player)
	return {
		"seats": seats.duplicate(),
		"leader": leader,
		"ready": ready_players,
		"code": code,
		"started": started,
		"game_size": game_size,
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
	var ready_read: Array = data.get("ready", [])
	for player in state.players():
		state._ready[player] = ready_read.has(player) or ready_read.has(float(player))
	return state


func _first_free_seat() -> int:
	for seat in range(1, game_size):
		if seats[seat] == 0:
			return seat
	return MONSTER_SEAT if seats[MONSTER_SEAT] == 0 else -1
