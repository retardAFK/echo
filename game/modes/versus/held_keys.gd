class_name HeldKeys
extends RefCounted
## The keys a Versus kit reads from its avatar's PlayerCommands (spec S-024,
## T-381): which are held, and which were pressed since the last frame, so a
## player on this machine and one played by the room act the same way.

var _last := 0
var _now := 0


## Reads this frame's held keys from commands.
func update(commands: PlayerCommands) -> void:
	_last = _now
	_now = 0
	for flag: int in [
		PlayerCommands.FLAG_INTERACT,
		PlayerCommands.FLAG_BREATH,
		PlayerCommands.FLAG_FIRE,
		PlayerCommands.FLAG_DODGE,
		PlayerCommands.FLAG_TOOL_1,
		PlayerCommands.FLAG_TOOL_2,
	]:
		if commands.is_held(flag):
			_now |= flag


## Whether the key of flag (PlayerCommands.FLAG_*) is held.
func held(flag: int) -> bool:
	return _now & flag != 0


## Whether it was pressed since the last frame.
func pressed(flag: int) -> bool:
	return _now & flag != 0 and _last & flag == 0


## Forgets what was held (nothing counts as pressed until let go).
func block() -> void:
	_last = _now
