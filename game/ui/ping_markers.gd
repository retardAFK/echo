class_name PingMarkers
extends CanvasLayer
## The team marks on a hunted's screen (spec S-020, T-328, piste A1): each
## Ping in view shows "Monstre · 12 m" or "Ici · 30 m" where it is, and fades
## in its last second. Added by HuntedHuds, so only the hunted see them
## (the room never sends them to the monster, NetGame).
## Pale blue, so it is never taken for the monster's orange noise markers.

const HERE_COLOR := Color(0.62, 0.8, 0.95)
const MONSTER_COLOR := Color(0.95, 0.55, 0.5)
## Height of the label above the marked point, in meters.
const LIFT := 1.2

## The labels in use, one per ping in view, oldest first.
var labels: Array[Label] = []


func _init() -> void:
	layer = 9
	name = "PingMarkers"


## The text of a mark seen from distance meters.
static func text_for(kind: Ping.Kind, distance: float) -> String:
	var key := "PING_MONSTER" if kind == Ping.Kind.MONSTER else "PING_HERE"
	return Text.t(key, roundi(distance))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var shown := 0
	if camera != null:
		for node in get_tree().get_nodes_in_group(Ping.GROUP):
			var ping := node as Ping
			var point := ping.global_position + Vector3.UP * LIFT
			if camera.is_position_behind(point):
				continue
			var label := _label(shown)
			shown += 1
			label.text = text_for(
				ping.kind, camera.global_position.distance_to(ping.global_position)
			)
			label.modulate = MONSTER_COLOR if ping.kind == Ping.Kind.MONSTER else HERE_COLOR
			label.modulate.a = clampf(ping.left, 0.0, 1.0)
			label.reset_size()
			label.position = camera.unproject_position(point) - label.size / 2.0
			label.visible = true
	for i in range(shown, labels.size()):
		labels[i].visible = false


func _label(index: int) -> Label:
	if index < labels.size():
		return labels[index]
	var label := Label.new()
	label.theme = preload("res://game/ui/theme/echo_theme.tres")
	label.theme_type_variation = &"HudLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels.append(label)
	return label
