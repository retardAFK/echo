class_name LocalControls
extends Node
## Turns the keyboard and mouse into PlayerCommands for the avatar it belongs
## to (S-010, T-106): the hunted Player or the playable monster. Added by the
## avatar itself when it is played on this machine; a remote avatar (T-095)
## gets its commands from the network instead.
## Mouse movement turns the avatar at once, so the view never waits.

var commands: PlayerCommands

@onready var _avatar: Node = get_parent()


func _unhandled_input(event: InputEvent) -> void:
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
		commands.push(PlayerCommands.Action.DECOY)
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only allow pointer capture right after a user gesture.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and captured:
		_avatar.look(event.screen_relative)


## Reads the keys held now and where the avatar looks. Called by the avatar at
## the start of its physics frame, so a key pressed this frame counts at once.
func fill() -> void:
	commands.seq += 1
	commands.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	commands.sprint = Input.is_action_pressed("sprint")
	commands.interact = Input.is_action_pressed("interact")
	commands.scan = Input.is_action_pressed("scan")
	commands.yaw = _avatar.rotation.y
	commands.pitch = _avatar.get_pitch()
