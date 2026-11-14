class_name IntercomLamp
extends Control
## The round call button of an intercom line (spec S-013, T-169): sodium and
## glowing when that player is ready, dark otherwise.

var lit := false:
	set(value):
		lit = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0 - 1.0
	var center := Vector2(size.x - radius - 1.0, size.y / 2.0)
	if lit:
		draw_circle(center, radius + 2.0, Color(MenuStyle.SODIUM, 0.35))
		draw_circle(center, radius, MenuStyle.SODIUM)
	else:
		draw_circle(center, radius, MenuStyle.KEY)
		draw_arc(center, radius, 0.0, TAU, 24, MenuStyle.METAL_EDGE, 1.5, true)
