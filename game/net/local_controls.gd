class_name LocalControls
extends Node
## Turns the keyboard and mouse into PlayerCommands for the avatar it belongs
## to (S-010, T-106): the hunted Player or the playable monster. Added by the
## avatar itself when it is played on this machine; a remote avatar (T-095)
## gets its commands from the network instead.
## Mouse movement turns the avatar at once, so the view never waits.

## True while the pause menu is open in an online game (S-013, Q6, T-164):
## the game goes on, the avatar stands still and takes no action.
static var frozen := false

var commands: PlayerCommands

@onready var _avatar: Node = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crouch"):
		commands.push(PlayerCommands.Action.CROUCH)
	elif event.is_action_pressed("interact"):
		commands.push(PlayerCommands.Action.INTERACT)
	elif event.is_action_pressed("throw") and captured:
		commands.push(PlayerCommands.Action.THROW)
	elif event.is_action_pressed("place_decoy") and captured:
		var short: bool = _avatar.get("decoy_short") == true
		commands.push(PlayerCommands.Action.DECOY_SHORT if short else PlayerCommands.Action.DECOY)
	elif event.is_action_pressed("decoy_delay") and "decoy_short" in _avatar:
		_avatar.set("decoy_short", not _avatar.get("decoy_short"))  # T-313.
	elif event.is_action_pressed("place_firecracker") and captured:
		commands.push(PlayerCommands.Action.FIRECRACKER)
	elif event.is_action_pressed("place_can_wire") and captured:
		commands.push(PlayerCommands.Action.CAN_WIRE)  # S-020, T-333.
	elif event.is_action_pressed("place_walkman") and captured:
		commands.push(PlayerCommands.Action.WALKMAN)  # S-020, T-334.
	elif event.is_action_pressed("ping") and captured and _avatar is Player:
		commands.push(PlayerCommands.Action.PING)  # Hunted only (T-328).
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only allow pointer capture right after a user gesture.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and captured:
		_avatar.look(Settings.adjust_look(event.screen_relative))


## Reads the keys held now and where the avatar looks. Called by the avatar at
## the start of its physics frame, so a key pressed this frame counts at once.
func fill() -> void:
	commands.seq += 1
	commands.move = (
		Vector2.ZERO
		if frozen
		else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	)
	commands.sprint = not frozen and Input.is_action_pressed("sprint")
	commands.interact = not frozen and Input.is_action_pressed("interact")
	commands.scan = not frozen and Input.is_action_pressed("scan")
	commands.hold_breath = not frozen and Input.is_action_pressed("hold_breath")
	commands.yaw = _avatar.rotation.y
	commands.pitch = _avatar.get_pitch()
