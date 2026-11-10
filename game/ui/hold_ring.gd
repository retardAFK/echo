class_name HoldRing
extends Control
## The ring around the crosshair that fills while the hunted holds "interact"
## (spec S-007, Q2).

const RADIUS := 7.0
const WIDTH := 1.5
const BACK := Color(1, 1, 1, 0.2)
const FILL := Color(1, 1, 1, 0.9)

## Progress from 0 to 1.
var ratio := 0.0:
	set(value):
		if not is_equal_approx(value, ratio):
			ratio = value
			queue_redraw()


func _draw() -> void:
	if ratio <= 0.0:
		return
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BACK, WIDTH, true)
	draw_arc(Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, FILL, WIDTH, true)
