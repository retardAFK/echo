class_name Transformer
extends Node3D
## The transformer of the cité, waiting for its fuses (spec S-007, Q3 and Q4).
## The hunted places each fuse they carry by holding "interact" next to it:
## repair_time per fuse, with a repair noise at the start and then regularly.
## Letting go keeps half of the fuse in progress; a placed fuse stays placed.
## Up close, a text says how many fuses it still waits for. Since S-018 it
## also takes the floppy disk of a download, placed the same way, and says
## when only other objectives remain.

## Emitted when a fuse is placed.
signal fuse_placed
## Emitted when the last fuse is placed.
signal repaired

@export var settings: LoopSettings
## Half the size of the transformer seen from above, in meters (x, z).
@export var half_size := Vector2(4.5, 3.5)

## The game whose fuses it counts.
var game_loop: GameLoop
var progress: HoldProgress

var _noise_left := 0.0

@onready var _label: Label3D = $WaitLabel
@onready var _sparks: AudioStreamPlayer3D = $Sparks
@onready var _hum: AudioStreamPlayer3D = $Hum
@onready var _siren: AudioStreamPlayer3D = $Siren


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	progress = HoldProgress.new(settings.repair_time, settings.kept_on_release)
	update_label()


func is_repaired() -> bool:
	return game_loop != null and game_loop.rules.is_repaired()


## Shows how many fuses are missing, hides itself once repaired (Q8).
func update_label() -> void:
	if game_loop == null or is_repaired():
		_label.visible = false
		return
	_label.visible = true
	var missing := game_loop.rules.missing()
	if missing == 0:
		_label.text = tr("HUD_TRANSFORMER_WAITS_OTHER")
		return
	var key := "HUD_TRANSFORMER_WAITS_ONE" if missing == 1 else "HUD_TRANSFORMER_WAITS"
	_label.text = tr(key) % missing


func get_prompt() -> String:
	if _carries_disk():
		return "HUD_INTERACT_TRANSFORMER_DISK"
	return "HUD_INTERACT_TRANSFORMER" if _has_fuse_to_place() else ""


## Whether a hunted standing there can place a fuse: it carries one, and it
## stands close to a side of the transformer.
func can_interact(from: Vector3) -> bool:
	if not _has_fuse_to_place():
		return false
	var local := global_transform.affine_inverse() * from
	var outside := Vector2(
		maxf(absf(local.x) - half_size.x, 0.0), maxf(absf(local.z) - half_size.y, 0.0)
	)
	return outside.length() <= settings.transformer_reach and absf(local.y) < 2.0


## A single press does nothing: a fuse is placed by holding.
func interact(_user: Node) -> void:
	pass


## Only a hunted with a fuse (or the floppy disk) in its pockets can repair
## (S-010, T-100).
func wanted_by(user: Node) -> bool:
	if game_loop == null:
		return false
	if game_loop.quests != null and game_loop.quests.carries_disk(user):
		return true
	return game_loop.carried_by(user) > 0


func hold(user: Node, delta: float) -> void:
	if not _has_fuse_to_place() or not wanted_by(user):
		return
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = settings.repair_noise_interval
		_sparks.play()
		NoiseBus.emit_noise(
			NoiseEvent.Type.REPAIR, global_position + Vector3.UP, settings.repair_noise_range, user
		)
	if progress.advance(delta):
		_noise_left = 0.0
		if game_loop.quests != null and game_loop.quests.carries_disk(user):
			game_loop.quests.place_disk(user)
		else:
			game_loop.place_fuse(user)
		update_label()
		fuse_placed.emit()
		if is_repaired():
			_hum.play()
			repaired.emit()


## The siren over the whole cité, once repaired (Q4). GameLoop sends its noise.
func start_siren() -> void:
	_siren.play()


func is_humming() -> bool:
	return _hum.playing


func release(_user: Node) -> void:
	progress.release()
	_noise_left = 0.0


func get_hold_ratio() -> float:
	return progress.get_ratio()


## Online client (S-010, T-099): the sparks of a repair in the room.
func voice() -> void:
	_sparks.play()


func _has_fuse_to_place() -> bool:
	if game_loop == null or is_repaired():
		return false
	return game_loop.rules.carried > 0 or _carries_disk()


## Someone carries the floppy disk of the download (S-018).
func _carries_disk() -> bool:
	return game_loop != null and game_loop.quests != null and game_loop.quests.is_disk_carried()
