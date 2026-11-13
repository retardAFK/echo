class_name LobbyState
extends RefCounted
## The waiting room of a game (S-010, Q6, T-096), kept by the room: four
## seats (the monster, then hunted 1 to 3), who sits where, who is ready, and
## the leader. A seat nobody sits in is played by an AI. Players are the
## numbers RoomLink gives them (1 to room_size). Pure, so tests need no network.

const MONSTER_SEAT := 0
const SEATS := 4

## Player in each seat, 0 for an AI.
var seats: Array[int] = [0, 0, 0, 0]
## The player who can swap seats and launch: the first one in, then the next.
var leader := 0
## Game code, shown in the waiting room.
var code := ""
var started := false

var _ready := {}


## A new player sits in the first free hunted seat, else the monster's.
## Returns false if every seat is taken or the game has started.
func add_player(player: int) -> bool:
	if started or seat_of(player) >= 0:
		return false
	var seat := _first_free_seat()
	if seat < 0:
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


## Moves a player to a free seat. Their "ready" is reset.
func take_seat(player: int, seat: int) -> bool:
	if started or seat < 0 or seat >= SEATS or seats[seat] != 0 or seat_of(player) < 0:
		return false
	seats[seat_of(player)] = 0
	seats[seat] = player
	_ready[player] = false
	return true


## The leader swaps the occupants of two seats (players or AI).
func swap(by: int, first: int, second: int) -> bool:
	if started or by != leader or first == second:
		return false
	if first < 0 or first >= SEATS or second < 0 or second >= SEATS:
		return false
	var moved := seats[first]
	seats[first] = seats[second]
	seats[second] = moved
	for player in [seats[first], seats[second]]:
		if player != 0:
			_ready[player] = false
	return true


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


func start(by: int) -> bool:
	if not can_start(by):
		return false
	started = true
	return true


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
	var ready_read: Array = data.get("ready", [])
	for player in state.players():
		state._ready[player] = ready_read.has(player) or ready_read.has(float(player))
	return state


func _first_free_seat() -> int:
	for seat in range(1, SEATS):
		if seats[seat] == 0:
			return seat
	return MONSTER_SEAT if seats[MONSTER_SEAT] == 0 else -1
