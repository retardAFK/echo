class_name MapScreen
extends CanvasLayer
## The hunted's map (spec S-017, T-252): the map key (Tab by default) opens
## and closes the plan of the map over the game. The game goes on behind it,
## alone as online, and the hunted can still move (S-017, Q3). The plan shows
## the place and where the player stands, nothing else (Q2). The monster has
## no map (Q1). It closes on its own when the game stops (pause, end of game)
## or when the online pause freezes the controls.

const ACTION := "map"

var plan: MapPlan:
	set(value):
		plan = value
		if _view != null:
			_view.plan = value
## The hunted shown on the plan.
var player: Node3D:
	set(value):
		player = value
		if _view != null:
			_view.player = value

@onready var _view: MapView = %View
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # To close when the game stops.
	_view.plan = plan
	_view.player = player
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION):
		return
	if visible:
		close()
	elif can_open():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and not can_open():
		close()


## Only while the game runs, on a map that has a plan.
func can_open() -> bool:
	return plan != null and not get_tree().paused and not LocalControls.frozen


func open() -> void:
	_title.text = tr(plan.title_key)
	_hint.text = Settings.fill(tr("MAP_HINT"))
	var objectives := objective_lines()
	if not objectives.is_empty():
		_hint.text = "\n".join(objectives) + "\n\n" + _hint.text
	visible = true
	_view.set_process(true)


## The objectives of the game and how far along they are (S-018, T-266):
## their names only, never where.
func objective_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var game_loop: GameLoop = get_parent().get("game_loop") if get_parent() != null else null
	if game_loop == null:
		return lines
	var rules := game_loop.rules
	if rules.fuse_count > 0:
		lines.append(tr("MAP_OBJECTIVE_FUSES") % [rules.placed, rules.fuse_count])
	for kind in [LoopRules.Objective.CODE, LoopRules.Objective.DOWNLOAD, LoopRules.Objective.RELAY]:
		if kind in rules.objectives:
			var key: String = "MAP_OBJECTIVE_" + LoopRules.Objective.keys()[kind]
			var done := "  " + tr("MAP_OBJECTIVE_DONE") if rules.is_done(kind) else ""
			lines.append(tr(key) + done)
	return lines


func close() -> void:
	visible = false
	_view.set_process(false)
