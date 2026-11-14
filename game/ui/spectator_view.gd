class_name SpectatorView
extends Node3D
## What a hunted out of the game sees (S-010, Q2, T-107): the view of a
## teammate still in the game, from its eyes, as the room sends it. A click
## or "interact" asks the room for the next teammate. GameMap adds it on a
## client when NetGame starts spectating.

## The client's NetGame: the watched seat, its pitch and the puppets.
var net: NetGame

var _camera := Camera3D.new()
var _hint := Label.new()
## The teammate whose eyes the camera uses: its body is hidden.
var _inside: NetPuppet


func _ready() -> void:
	add_child(_camera)
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_hint.text = "HUD_SPECTATOR"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -60.0
	_hint.offset_bottom = -30.0
	_hint.offset_left = -300.0
	_hint.offset_right = 300.0
	layer.add_child(_hint)
	_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed
	if (click or event.is_action_pressed("interact")) and net.own != null:
		net.own.commands.push(PlayerCommands.Action.INTERACT)


func _process(_delta: float) -> void:
	var puppet: NetPuppet = net.puppets.get(net.watched_seat)
	_hint.visible = puppet != null
	if puppet != _inside:  # Its own body would hide the view (S-011).
		if is_instance_valid(_inside):
			_inside.set_seen_from_inside(false)
		_inside = puppet
		if puppet != null:
			puppet.set_seen_from_inside(true)
	if puppet == null:
		return
	_camera.global_position = puppet.global_position + Vector3.UP * puppet.get_eye_height()
	_camera.global_rotation = Vector3(net.watched_pitch, puppet.rotation.y, 0.0)
	# The ears follow the view: noises are heard where the teammate is.
	net.own.global_position = puppet.global_position
