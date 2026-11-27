class_name BossLook
extends Node
## How the Versus boss looks (spec S-025, Q8, T-405): its model bigger
## (boss_scale), with glowing orange cracks (boss_glow.gdshader over every
## mesh of its MonsterBody) that grow stronger in each phase (VersusPhase
## glow) and in its fury. A child of the boss's body: the AI monster or a
## human's avatar, on the room and on the clients.
## Its collision stays the monster's own (it still passes the 2.4 m doors);
## a hitbox of its new size (a StaticBody3D on HITBOX_LAYER, which nothing
## walks into) takes the shots instead, its head included.

const SHADER := preload("res://game/modes/versus/boss_glow.gdshader")
## Physics layer 9: only the shots look for it.
const HITBOX_LAYER := 1 << 8
## The monster's own capsule, scaled for the hitbox.
const RADIUS := 0.35
const HEIGHT := 2.2

var mode: VersusMode
var body: Node3D
var hitbox: StaticBody3D
var _material: ShaderMaterial


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "BossLook"


func _ready() -> void:
	body = get_parent()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var scale := mode.settings.boss_scale
	hitbox = StaticBody3D.new()
	hitbox.name = "BossHitbox"
	hitbox.collision_layer = HITBOX_LAYER
	hitbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS * scale
	capsule.height = HEIGHT * scale
	shape.shape = capsule
	shape.position.y = HEIGHT * scale * 0.5
	hitbox.add_child(shape)
	body.add_child(hitbox)


func _process(_delta: float) -> void:
	_dress()
	_material.set_shader_parameter("strength", glow())


## How strong its cracks glow now: its phase's glow, more in its fury.
func glow() -> float:
	var health := mode.boss_health()
	if health == null:
		return 0.0
	var phase := health.current_phase()
	var amount := phase.glow if phase != null else 0.4
	return amount * (1.6 if health.in_fury() else 1.0)


## Its MonsterBody models (one, or a new one the view added) made bigger and
## cracked, once each.
func _dress() -> void:
	for child in body.get_children():
		if not child is MonsterBody or child.has_meta(&"boss_look"):
			continue
		var model := child as Node3D
		model.scale = Vector3.ONE * mode.settings.boss_scale
		var meshes := model.find_children("*", "GeometryInstance3D", true, false)
		if meshes.is_empty() and DisplayServer.get_name() != "headless":
			continue  # Its model comes a frame later.
		for mesh in meshes:
			(mesh as GeometryInstance3D).material_overlay = _material
		model.set_meta(&"boss_look", true)
