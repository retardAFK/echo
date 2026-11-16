class_name PlayerCommands
extends RefCounted
## What a player asks its avatar to do this physics frame (S-010, T-106):
## the keys and buttons held, where it looks, and the one-shot actions pressed
## since the last frame. Filled from the keyboard and mouse by LocalControls,
## or, later, received from the network (T-095). Avatars read it instead of
## Input, so the same code moves a local player and a remote one.

## A one-shot action was queued, so the network can send it reliably (T-095).
signal action_pushed(action: Action)

## One-shot actions, applied once by the avatar.
enum Action { CROUCH, INTERACT, THROW, DECOY }

## A line picked in a terminal's menu (S-018): PICK_BASE + its number, from
## 0, so a tampered client picks only lines the menu has, and nothing else.
const PICK_BASE := 32
const PICK_COUNT := 16

## Held flags, packed in one byte by to_bytes().
const FLAG_SPRINT := 1
const FLAG_INTERACT := 2
const FLAG_SCAN := 4
## Bytes before the actions: seq (4), move (2 x 4), yaw (4), pitch (4), flags (1), count (1).
const HEADER_SIZE := 22

## Increases with every frame sent, so the receiver can drop old ones.
var seq := 0
## Movement input, x = right, y = back, length at most 1.
var move := Vector2.ZERO
## Where the avatar looks, in radians: body yaw and head pitch.
var yaw := 0.0
var pitch := 0.0
var sprint := false
var interact := false
var scan := false

var _actions: Array[Action] = []


## Queues a one-shot action for the next frame.
func push(action: Action) -> void:
	_actions.append(action)
	action_pushed.emit(action)


## Queues the pick of line n (from 0) of a terminal's menu.
func push_pick(n: int) -> void:
	if n >= 0 and n < PICK_COUNT:
		push((PICK_BASE + n) as Action)


## The line an action picks, or -1 if it is not a pick.
static func picked(action: int) -> int:
	return action - PICK_BASE if action >= PICK_BASE and action < PICK_BASE + PICK_COUNT else -1


## Copies what is held and where it looks (not the queued actions) from other.
func copy_held(other: PlayerCommands) -> void:
	seq = other.seq
	move = other.move
	yaw = other.yaw
	pitch = other.pitch
	sprint = other.sprint
	interact = other.interact
	scan = other.scan


## The queued one-shot actions, oldest first; the queue is emptied.
func take_actions() -> Array[Action]:
	var taken := _actions
	_actions = []
	return taken


## The queued actions, left in the queue.
func peek_actions() -> Array[Action]:
	return _actions.duplicate()


## Compact form for the network: 22 bytes plus one per queued action.
func to_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + _actions.size())
	bytes.encode_u32(0, seq)
	bytes.encode_float(4, move.x)
	bytes.encode_float(8, move.y)
	bytes.encode_float(12, yaw)
	bytes.encode_float(16, pitch)
	var flags := 0
	if sprint:
		flags |= FLAG_SPRINT
	if interact:
		flags |= FLAG_INTERACT
	if scan:
		flags |= FLAG_SCAN
	bytes.encode_u8(20, flags)
	bytes.encode_u8(21, _actions.size())
	for i in _actions.size():
		bytes.encode_u8(HEADER_SIZE + i, _actions[i])
	return bytes


## Reads what to_bytes() wrote, or returns null if the bytes are malformed.
## Movement is clamped to length 1 and unknown actions are dropped, so a
## tampered client cannot move faster or invent actions.
static func from_bytes(bytes: PackedByteArray) -> PlayerCommands:
	if bytes.size() < HEADER_SIZE:
		return null
	var count := bytes.decode_u8(21)
	if bytes.size() != HEADER_SIZE + count:
		return null
	var commands := PlayerCommands.new()
	commands.seq = bytes.decode_u32(0)
	var move := Vector2(bytes.decode_float(4), bytes.decode_float(8))
	commands.move = move.limit_length(1.0) if move.is_finite() else Vector2.ZERO
	var yaw := bytes.decode_float(12)
	var pitch := bytes.decode_float(16)
	commands.yaw = yaw if is_finite(yaw) else 0.0
	commands.pitch = pitch if is_finite(pitch) else 0.0
	var flags := bytes.decode_u8(20)
	commands.sprint = flags & FLAG_SPRINT != 0
	commands.interact = flags & FLAG_INTERACT != 0
	commands.scan = flags & FLAG_SCAN != 0
	for i in count:
		var action := bytes.decode_u8(HEADER_SIZE + i)
		if action < Action.size() or picked(action) >= 0:
			commands.push(action as Action)
	return commands
