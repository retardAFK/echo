class_name MapView
extends Control
## Draws a MapPlan (spec S-017, T-252), like the plan at the entrance of a
## housing estate: the edges of the map, the paths, the blocks and their
## names, a grid, the north, and "you are here" where the player stands.
## Every building looks the same, so the plan says nothing about where the
## fuses may be (S-017, Q2). Colors from the menu style, never the noise
## orange (rule 2.3).

## Space around the plan, in pixels of the 640 x 360 base.
const MARGIN := 18.0
## Grid step, in meters, as on the paper plan of S-006.
const GRID_STEP := 20.0
## Names on the plan: font size, and the smallest size before a name is dropped.
const LABEL_SIZE := 8
const LABEL_MIN_SIZE := 5
## Room left around a name inside its rectangle, in pixels.
const LABEL_PADDING := 2.0
## "You are here": length of the arrow and radius of its halo, in pixels.
const MARKER_LENGTH := 11.0
const MARKER_HALO := 10.0
## The halo breathes slowly, so the eye finds it (cycles per second).
const MARKER_PULSE := 0.8
const NORTH_SIZE := 6.0

const GROUND := Color("1d1c19")
const GRID := Color(0.85, 0.8, 0.68, 0.06)
const EDGE := Color("2c2a25")
const PATH := Color("3b3933")
const PLACE_LINE := Color("6e685a")
const BLOCK := Color("5a564c")
const BLOCK_LINE := Color("8c8572")
const STRUCTURE := Color("47443c")
const FRAME := Color("8c8572")

var plan: MapPlan
## The node shown as "you are here"; nothing is shown without one.
var player: Node3D

var _font: Font
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(MenuStyle.FONT_DISPLAY)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # The marker moves and turns with the player.


## The square the plan is drawn in, in this control's space.
func plan_area() -> Rect2:
	if plan == null:
		return Rect2()
	var room := size - Vector2.ONE * MARGIN * 2.0
	var scale_factor := minf(room.x / plan.size.x, room.y / plan.size.y)
	var drawn := plan.size * scale_factor
	return Rect2((size - drawn) / 2.0, drawn)


## A plan point in this control's space.
func to_view(point: Vector2) -> Vector2:
	var area := plan_area()
	return area.position + point / plan.size * area.size


func _draw() -> void:
	if plan == null:
		return
	var area := plan_area()
	draw_rect(area, GROUND)
	_draw_grid(area)
	for i in plan.rects.size():
		_draw_rect(plan.rects[i], plan.kinds[i])
	draw_rect(area, FRAME, false, 1.0)
	for i in plan.rects.size():
		if not plan.labels[i].is_empty():
			_draw_label(plan.rects[i], plan.kinds[i], tr(plan.labels[i]))
	_draw_north(area)
	_draw_player()


func _draw_grid(area: Rect2) -> void:
	var step := GRID_STEP
	while step < plan.size.x:
		var x := to_view(Vector2(step, 0)).x
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), GRID)
		step += GRID_STEP
	step = GRID_STEP
	while step < plan.size.y:
		var y := to_view(Vector2(0, step)).y
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), GRID)
		step += GRID_STEP


func _view_rect(rect: Rect2) -> Rect2:
	var from := to_view(rect.position)
	return Rect2(from, to_view(rect.end) - from)


func _draw_rect(rect: Rect2, kind: int) -> void:
	var drawn := _view_rect(rect)
	match kind:
		MapPlan.Kind.EDGE:
			draw_rect(drawn, EDGE)
		MapPlan.Kind.PATH:
			draw_rect(drawn, PATH)
		MapPlan.Kind.PLACE:
			draw_rect(drawn, PLACE_LINE, false, 1.0)
		MapPlan.Kind.STRUCTURE:
			draw_rect(drawn, STRUCTURE)
		_:
			draw_rect(drawn, BLOCK)
			draw_rect(drawn, BLOCK_LINE, false, 1.0)


## A name in the middle of its rectangle, turned along a tall one, smaller if
## it does not fit, left out if it still does not.
func _draw_label(rect: Rect2, kind: int, text: String) -> void:
	var drawn := _view_rect(rect)
	var tall := drawn.size.y > drawn.size.x
	var room := (
		(Vector2(drawn.size.y, drawn.size.x) if tall else drawn.size)
		- Vector2.ONE * LABEL_PADDING * 2.0
	)
	var font_size := LABEL_SIZE
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	while font_size > LABEL_MIN_SIZE and (text_size.x > room.x or text_size.y > room.y):
		font_size -= 1
		text_size = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if text_size.x > room.x and kind != MapPlan.Kind.EDGE:
		return
	var color := MenuStyle.MUTED if kind == MapPlan.Kind.EDGE else MenuStyle.TEXT
	if kind == MapPlan.Kind.PLACE:
		color = MenuStyle.MUTED
	var baseline := Vector2(-text_size.x / 2.0, _font.get_ascent(font_size) - text_size.y / 2.0)
	draw_set_transform(drawn.get_center(), -PI / 2.0 if tall else 0.0)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform(Vector2.ZERO)


func _draw_north(area: Rect2) -> void:
	var tip := Vector2(area.end.x + MARGIN / 2.0, area.position.y + NORTH_SIZE)
	var points := PackedVector2Array(
		[
			tip,
			tip + Vector2(-NORTH_SIZE / 2.0, NORTH_SIZE),
			tip + Vector2(NORTH_SIZE / 2.0, NORTH_SIZE)
		]
	)
	draw_colored_polygon(points, MenuStyle.MUTED)
	var below := tip + Vector2(0, NORTH_SIZE * 2.6)
	var width := _font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(
		_font,
		below - Vector2(width / 2.0, 0),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_SIZE,
		MenuStyle.MUTED
	)


func _draw_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var at := to_view(plan.to_plan(player.global_position))
	var pulse := 0.5 + 0.5 * sin(_time * TAU * MARKER_PULSE)
	var halo := MenuStyle.SODIUM
	halo.a = 0.12 + 0.18 * pulse
	draw_circle(at, MARKER_HALO, halo)
	var heading := MapPlan.heading(player)
	var forward := Vector2(sin(heading), -cos(heading))
	var side := Vector2(-forward.y, forward.x)
	var tip := at + forward * MARKER_LENGTH * 0.6
	var back := at - forward * MARKER_LENGTH * 0.4
	var points := PackedVector2Array(
		[
			tip,
			back + side * MARKER_LENGTH * 0.4,
			at - forward * MARKER_LENGTH * 0.15,
			back - side * MARKER_LENGTH * 0.4
		]
	)
	draw_colored_polygon(points, MenuStyle.SODIUM)
	points.append(tip)
	draw_polyline(points, MenuStyle.INK, 1.0)
