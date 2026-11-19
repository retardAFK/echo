class_name CommandQueue
extends RefCounted
## Room side: the frames of commands of one player, played exactly one per
## physics frame (S-020, T-321). Each packet from the client carries its last
## frames, each with its number: the queue keeps them in order, drops those
## already played or already queued, and keeps a lead of a few frames to ride
## out the bursts of the WebSocket. With nothing queued, it plays the last
## frame again without moving the number on, so the number the room sends
## back is always the frame it really played.
## One-shot actions come reliably, each with the number of its frame: played
## with that frame, once, never lost.

## Frames queued before the first is played, and the lead aimed at after a
## starve.
var lead := 3
## Beyond this many queued, the oldest are dropped, so a burst does not add
## lasting lag.
var max_backlog := 8
## Room frames an action waits for a frame not received yet before it is
## played anyway (the client stopped sending). A frame lost beyond the
## redundancy is seen at once: newer frames came, not it.
var action_wait := 30
## The frame played last (seq 0: nothing played yet).
var played := PlayerCommands.new()
## The newest frame received, played or not.
var newest_seq := 0

var _frames: Array[PlayerCommands] = []
var _actions: Array = []  # [seq, action, frames waited], in arrival order.
var _starving := true


func _init(settings: NetSettings = null) -> void:
	if settings != null:
		lead = settings.command_lead
		max_backlog = settings.command_max_backlog


## Frames received in one packet, in any order.
func receive(frames: Array[PlayerCommands]) -> void:
	for frame in frames:
		if frame == null or frame.seq <= played.seq or _has(frame.seq):
			continue
		var at := _frames.size()
		while at > 0 and _frames[at - 1].seq > frame.seq:
			at -= 1
		_frames.insert(at, frame)
		newest_seq = maxi(newest_seq, frame.seq)


## A one-shot action of the frame seq.
func add_action(seq: int, action: int) -> void:
	_actions.append([seq, action, 0])


func size() -> int:
	return _frames.size()


## The frame to play this physics frame, with its actions queued in it.
func next() -> PlayerCommands:
	while _frames.size() > max_backlog:
		_frames.pop_front()  # A burst: catch up rather than lag behind.
	if _starving and _frames.size() >= lead:
		_starving = false
	var frame := PlayerCommands.new()
	if _starving or _frames.is_empty():
		_starving = true
		frame.copy_held(played)  # The same number: nothing new was played.
	else:
		frame = _frames.pop_front()
		frame.take_actions()  # Actions only come through add_action().
	played = PlayerCommands.new()
	played.copy_held(frame)
	var waiting: Array = []
	for entry: Array in _actions:
		if _action_due(entry, frame.seq):
			frame.push(entry[1] as PlayerCommands.Action)
		else:
			waiting.append(entry)
	_actions = waiting
	return frame


## Whether the action [seq, action, waited] plays with the frame now played:
## its own frame, or the last one before a frame that will never come.
func _action_due(entry: Array, now: int) -> bool:
	var seq: int = entry[0]
	if seq <= now:
		return true
	if _has(seq):
		return false  # Its frame is queued: it comes with it.
	if newest_seq >= seq:
		# Newer frames came, not its own (lost): with the last frame before it.
		return _frames.is_empty() or _frames[0].seq > seq
	entry[2] += 1
	return entry[2] > action_wait


func _has(seq: int) -> bool:
	for frame in _frames:
		if frame.seq == seq:
			return true
	return false
