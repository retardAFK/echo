class_name LoadingScreen
extends Control
## Loading screen (spec S-013, T-166): a view of the cité, a progress bar and
## a tip of the role being played while the map loads. The web build has no
## threads, so the map loads in steps, one per frame: its dependencies within
## a time budget, then the scene, then its instance, and the bar moves
## between them. The first time a role is played, its first steps are shown
## instead of a tip and the game waits for Enter or a click (never online,
## where the others are waiting); the next times it starts as soon as loaded.

## The map is ready: emitted instead of changing the scene (tests).
signal loaded(scene: Node)
## The bar moved, 0 to 1.
signal progressed(value: float)

const SCENE_PATH := "res://game/ui/loading_screen.tscn"
## Lines of the first steps, and tips, of each role in game/i18n/strings.csv.
const FIRST_STEPS := 3
const TIPS := {GameSession.Role.HUNTED: 5, GameSession.Role.MONSTER: 4}
## Where the bar stands once the dependencies, then the scene, are loaded.
const AFTER_DEPENDENCIES := 0.25
const AFTER_SCENE := 0.7
## Time spent loading dependencies in one frame, in milliseconds.
const FRAME_BUDGET_MS := 40

## The scene the next loading screen loads (set by open()).
static var target := ""

## Tests turn this off: "loaded" is emitted and the scene is not changed.
@export var change_scene := true
## Online, the room waits for every player: the game starts once loaded.
@export var wait_first_time := true

## 0 to 1.
var progress := 0.0
var role := GameSession.Role.HUNTED

var _path := ""
var _dependencies: PackedStringArray = []
var _next_dependency := 0
## Loaded dependencies, kept so they stay in the cache until the scene loads.
var _kept: Array[Resource] = []
var _packed: PackedScene
var _scene: Node
var _first_steps := false
var _done := false

@onready var _heading: Label = %Heading
@onready var _tips: Label = %Tips
@onready var _bar: ColorRect = %Fill
@onready var _status: Label = %Status


## Shows the loading screen, which then loads the scene at this path.
static func open(tree: SceneTree, scene_path: String) -> void:
	target = scene_path
	tree.change_scene_to_file(SCENE_PATH)


static func flag_of(of_role: GameSession.Role) -> String:
	return "first_steps_monster" if of_role == GameSession.Role.MONSTER else "first_steps_hunted"


## Translation keys of the first steps, or of the tips, of a role.
static func tip_keys(of_role: GameSession.Role, first: bool) -> Array[String]:
	var prefix := "TIP_MONSTER_" if of_role == GameSession.Role.MONSTER else "TIP_HUNTED_"
	var keys: Array[String] = []
	for i in FIRST_STEPS if first else TIPS[of_role]:
		keys.append(prefix + ("FIRST_%d" if first else "%d") % (i + 1))
	return keys


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	role = GameSession.role
	if NetSession.mode != NetSession.Mode.SOLO:
		wait_first_time = false
	_first_steps = not Settings.get_value(flag_of(role))
	_show_tips()
	if _path == "":
		start(target)


## Loads this scene (a path under res://).
func start(path: String) -> void:
	_path = path
	_dependencies = ResourceLoader.get_dependencies(path)
	_next_dependency = 0
	_set_progress(0.0)


func _process(_delta: float) -> void:
	if _path == "" or _done:
		return
	if _next_dependency < _dependencies.size():
		_load_dependencies()
	elif _packed == null:
		_packed = load(_path)
		_kept.clear()
		_set_progress(AFTER_SCENE)
	elif _scene == null:
		_scene = _packed.instantiate()
		_set_progress(1.0)
		_done = true
		if _first_steps and wait_first_time:
			_status.text = Text.with_keys("LOADING_READY")
		else:
			finish()


func _unhandled_input(event: InputEvent) -> void:
	if not (_done and _scene != null and _first_steps and wait_first_time):
		return
	var click: bool = event is InputEventMouseButton and event.pressed
	if event.is_action_pressed("ui_accept") or click:
		get_viewport().set_input_as_handled()
		Settings.set_value(flag_of(role), true)
		finish()


## Whether the screen waits for Enter or a click before starting.
func is_waiting() -> bool:
	return _done and _scene != null and _first_steps and wait_first_time


## Puts the loaded scene in place of this screen.
func finish() -> void:
	var scene := _scene
	_scene = null
	set_process_unhandled_input(false)
	if not change_scene:
		loaded.emit(scene)
		return
	var tree := get_tree()
	tree.root.add_child(scene)
	tree.current_scene = scene
	queue_free()


func _load_dependencies() -> void:
	var start_msec := Time.get_ticks_msec()
	while (
		_next_dependency < _dependencies.size()
		and Time.get_ticks_msec() - start_msec < FRAME_BUDGET_MS
	):
		var dependency := _dependencies[_next_dependency]
		# "uid://…::Type::res://path" or a bare path.
		var path := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
		var resource := load(path)
		if resource != null:
			_kept.append(resource)
		_next_dependency += 1
	_set_progress(AFTER_DEPENDENCIES * _next_dependency / maxf(_dependencies.size(), 1.0))


func _set_progress(value: float) -> void:
	progress = value
	_bar.anchor_right = value
	_status.text = Text.t("LOADING_STEP", roundi(value * 100.0))
	progressed.emit(value)


func _show_tips() -> void:
	_heading.text = Text.t("LOADING_FIRST_STEPS" if _first_steps else "LOADING_TIP")
	var keys := tip_keys(role, _first_steps)
	if not _first_steps:
		keys = [keys.pick_random()]
	var lines: PackedStringArray = []
	for key in keys:
		lines.append(Text.with_keys(key))
	_tips.text = "\n\n".join(lines)


func get_tips() -> String:
	return _tips.text
