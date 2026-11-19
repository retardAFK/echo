class_name CodeSpot
extends Node3D
## A place where the transformer's code may be written (spec S-018, Q13): a
## post-it on the wall behind a terminal's desk, read up close. One is drawn
## when the game has a CODE objective; it shows the 4 digits, the others stay
## blank. It stands on the wall, its front toward +Z.
##
## Reading (T-271, after Maxime's test: "there seems to be no code on the
## post-its"): the digits are big, dark ink on the paper, and PostItReader
## also writes on the HUD what a post-it in front of the crosshair says, the
## code or "blank". A post-it read with the code is remembered (was_read) on
## this computer only, for the map screen's objective line and the keypad.

const GROUP := &"code_spots"
## The digits are drawn only from this close, in meters.
const READ_DISTANCE := 15.0

## The hunted of this computer read the code on it (T-271).
var was_read := false

@onready var _label: Label3D = $Digits


func _ready() -> void:
	add_to_group(GROUP)
	_label.visibility_range_end = READ_DISTANCE
	DrawRange.limit(self, DrawRange.INDOOR)
	show_code("")


## Writes the code on it, or leaves it blank ("").
func show_code(code: String) -> void:
	if code != _label.text:
		was_read = false
	_label.text = code
	_label.visible = code != ""


func get_code() -> String:
	return _label.text if _label.visible else ""


## Whether eyes at `eye`, looking along `forward`, read it: in front of the
## post-it, within `reach` meters and `angle` radians of the crosshair.
func readable_from(eye: Vector3, forward: Vector3, reach: float, angle: float) -> bool:
	var gap := global_position - eye
	if gap.length() > reach or gap.length() < 0.01:
		return false
	if gap.dot(global_basis.z) >= 0.0:
		return false  # Behind the wall.
	return forward.normalized().dot(gap.normalized()) >= cos(angle)


## The post-it of the code that the hunted of this computer read, if any.
static func read_code_spot(tree: SceneTree) -> CodeSpot:
	for spot: CodeSpot in tree.get_nodes_in_group(GROUP):
		if spot.was_read and spot.get_code() != "":
			return spot
	return null
