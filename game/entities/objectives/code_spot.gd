class_name CodeSpot
extends Node3D
## A place where the transformer's code may be written (spec S-018, Q13): a
## post-it on a wall, read up close. One is drawn when the game has a CODE
## objective; it shows the 4 digits, the others stay blank. It stands on the
## wall, its front toward +Z.

const GROUP := &"code_spots"
## The digits are read only from this close, in meters.
const READ_DISTANCE := 15.0

@onready var _label: Label3D = $Digits
@onready var _paper: MeshInstance3D = $Paper


func _ready() -> void:
	add_to_group(GROUP)
	_label.visibility_range_end = READ_DISTANCE
	DrawRange.limit(self, DrawRange.INDOOR)
	show_code("")


## Writes the code on it, or leaves it blank ("").
func show_code(code: String) -> void:
	_label.text = code
	_label.visible = code != ""


func get_code() -> String:
	return _label.text if _label.visible else ""
