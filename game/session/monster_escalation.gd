class_name MonsterEscalation
extends Node
## The monster's rise (spec S-023, Q5 to Q7, T-354): each objective the hunted
## do gives every monster of the game (played or AI, solo, room or client) the
## next stage of the EscalationList. A child of the GameLoop, which it reads
## (rules.done_count()) and through which it says so (escalated). A monster
## that comes in later (an AI taking a player's place) gets the stages already
## reached. Each monster has its own copy of its MonsterSettings, so a stage
## changes it only. To remove the rise: an empty list in escalation.tres.

## Set before it enters the tree.
var game_loop: GameLoop
## The stages; the game's list when left null (tests give their own).
var list: EscalationList
## Stages reached so far (0 until the first objective is done).
var stage := 0

## Stage each monster already got: instance id -> stages given.
var _given := {}
var _check_left := 0.0


func _ready() -> void:
	if list == null:
		list = EscalationList.default()
	game_loop.fuses_changed.connect(_on_progress.unbind(2))


func _physics_process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0 and stage > 0:
		_check_left = 1.0  # A monster that came in since gets its stages.
		_give_all()


func _on_progress() -> void:
	var reached := mini(game_loop.rules.done_count(), list.stages.size())
	if reached <= stage:
		return
	stage = reached
	_give_all()
	game_loop.escalated.emit(stage)


func _give_all() -> void:
	for node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		var settings: Variant = node.get(&"settings")
		if not settings is MonsterSettings:
			continue
		var given: int = _given.get(node.get_instance_id(), 0)
		if given < stage:
			list.apply(settings, given, stage)
			_given[node.get_instance_id()] = stage
