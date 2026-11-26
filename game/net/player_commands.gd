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
## DECOY_SHORT: an alarm clock set to ring sooner (S-020, T-313).
## PING: a mark for the teammates (S-020, T-328).
## GADGET_1, GADGET_2: use the gadget of the first or second slot of the
## hunted's Loadout (S-023, T-353).
enum Action {
	CROUCH,
	INTERACT,
	THROW,
	DECOY,
	GADGET_1,
	DECOY_SHORT,
	PING,
	GADGET_2,
	SECOND_WIND,
}

## A line picked in a terminal's menu (S-018): PICK_BASE + its number, from
## 0, so a tampered client picks only lines the menu has, and nothing else.
const PICK_BASE := 32
const PICK_COUNT := 16

## Held flags, packed in one byte by to_bytes().
const FLAG_SPRINT := 1
const FLAG_INTERACT := 2
const FLAG_SCAN := 4
const FLAG_BREATH := 8
## Held keys of the Versus mode (S-024, T-381): left click (fire, claw),
## Space (roll, charge), and the two tool keys. Its kits turn presses into
## actions themselves, so a remote player plays like a local one.
const FLAG_FIRE := 16
const FLAG_DODGE := 32
const FLAG_TOOL_1 := 64
const FLAG_TOOL_2 := 128
## Bytes before the actions: seq (4), move (2 x 4), yaw (4), pitch (4), flags (1), count (1).
const HEADER_SIZE := 22
## Bytes of one frame in a packet of frames: the header without the count.
const FRAME_SIZE := 21
## Frames in one packet at most.
const MAX_FRAMES := 16

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
## Holding its breath (S-020, T-311).
var hold_breath := false
## Left click, Space and the tool keys held (S-024, T-381).
var fire := false
var dodge := false
var tool_1 := false
var tool_2 := false

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
	hold_breath = other.hold_breath
	fire = other.fire
	dodge = other.dodge
	tool_1 = other.tool_1
	tool_2 = other.tool_2


## Whether the key of flag (FLAG_*) is held.
func is_held(flag: int) -> bool:
	var held := {
		FLAG_SPRINT: sprint,
		FLAG_INTERACT: interact,
		FLAG_SCAN: scan,
		FLAG_BREATH: hold_breath,
		FLAG_FIRE: fire,
		FLAG_DODGE: dodge,
		FLAG_TOOL_1: tool_1,
		FLAG_TOOL_2: tool_2,
	}
	return held.get(flag, false)


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
	_encode_held(bytes, 0)
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
	var commands := _decode_held(bytes, 0)
	for i in count:
		var action := bytes.decode_u8(HEADER_SIZE + i)
		if action < Action.size() or picked(action) >= 0:
			commands.push(action as Action)
	return commands


## Several frames of held commands in one packet (S-020, T-321): a count,
## then FRAME_SIZE bytes per frame, oldest first. Queued actions are not in
## it: they go reliably on their own, with the number of their frame.
static func frames_to_bytes(frames: Array[PlayerCommands]) -> PackedByteArray:
	var count := mini(frames.size(), MAX_FRAMES)
	var first := frames.size() - count
	var bytes := PackedByteArray()
	bytes.resize(1 + FRAME_SIZE * count)
	bytes.encode_u8(0, count)
	for i in count:
		frames[first + i]._encode_held(bytes, 1 + FRAME_SIZE * i)
	return bytes


## Reads what frames_to_bytes() wrote; empty if the bytes are malformed.
static func frames_from_bytes(bytes: PackedByteArray) -> Array[PlayerCommands]:
	var frames: Array[PlayerCommands] = []
	if bytes.is_empty():
		return frames
	var count := bytes.decode_u8(0)
	if count > MAX_FRAMES or bytes.size() != 1 + FRAME_SIZE * count:
		return frames
	for i in count:
		frames.append(_decode_held(bytes, 1 + FRAME_SIZE * i))
	return frames


## Writes seq, move, yaw, pitch and the held flags at offset (FRAME_SIZE bytes).
func _encode_held(bytes: PackedByteArray, offset: int) -> void:
	bytes.encode_u32(offset, seq)
	bytes.encode_float(offset + 4, move.x)
	bytes.encode_float(offset + 8, move.y)
	bytes.encode_float(offset + 12, yaw)
	bytes.encode_float(offset + 16, pitch)
	var flags := 0
	if sprint:
		flags |= FLAG_SPRINT
	if interact:
		flags |= FLAG_INTERACT
	if scan:
		flags |= FLAG_SCAN
	if hold_breath:
		flags |= FLAG_BREATH
	for flag: int in [FLAG_FIRE, FLAG_DODGE, FLAG_TOOL_1, FLAG_TOOL_2]:
		if is_held(flag):
			flags |= flag
	bytes.encode_u8(offset + 20, flags)


## Reads what _encode_held() wrote, with movement clamped to length 1.
static func _decode_held(bytes: PackedByteArray, offset: int) -> PlayerCommands:
	var commands := PlayerCommands.new()
	commands.seq = bytes.decode_u32(offset)
	var move := Vector2(bytes.decode_float(offset + 4), bytes.decode_float(offset + 8))
	commands.move = move.limit_length(1.0) if move.is_finite() else Vector2.ZERO
	var yaw := bytes.decode_float(offset + 12)
	var pitch := bytes.decode_float(offset + 16)
	commands.yaw = yaw if is_finite(yaw) else 0.0
	commands.pitch = pitch if is_finite(pitch) else 0.0
	var flags := bytes.decode_u8(offset + 20)
	commands.sprint = flags & FLAG_SPRINT != 0
	commands.interact = flags & FLAG_INTERACT != 0
	commands.scan = flags & FLAG_SCAN != 0
	commands.hold_breath = flags & FLAG_BREATH != 0
	commands.fire = flags & FLAG_FIRE != 0
	commands.dodge = flags & FLAG_DODGE != 0
	commands.tool_1 = flags & FLAG_TOOL_1 != 0
	commands.tool_2 = flags & FLAG_TOOL_2 != 0
	return commands
