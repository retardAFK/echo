class_name VersusChest
extends StaticBody3D
## A chest of the Versus (spec S-024, Q29 to Q33, T-377): a khaki military
## trunk with metal corners. A hunted aims at it and holds interact
## (chest_open_time) to open it: the lid bangs (a noise of chest_noise_range,
## the boss hears where one gears up) and a red glow comes out. An open chest
## stays open; what is in it shows above it, and a hunted takes it by holding
## interact again (chest_take_time), leaving its old weapon or tool inside.
## A gun in an open chest shows its rarity (S-025, Q3, T-404): its name in
## that color and a beam of light above the chest, seen from afar.
## Prototype look: boxes; the real model comes with T-385.

signal opened

const GROUP := &"versus_chests"
const WALLS_LAYER := 1 << 1
const SIZE := Vector3(0.9, 0.5, 0.5)
const KHAKI := Color(0.33, 0.36, 0.22)
const CORNER := Color(0.3, 0.3, 0.3)
const GLOW := Color(0.9, 0.15, 0.1)
const LID_OPEN := -1.9
## Beyond this, in meters, its meshes are not drawn.
const VISIBLE_RANGE := 60.0
## Height of the rarity beam, and how far it is seen.
const BEAM_HEIGHT := 7.0
const BEAM_RANGE := 150.0
const MATERIAL := preload("res://game/modes/versus/data/chest_material.tres")

var item: VersusItem
var is_open := false
## The rarities of the guns (settings.rarities), for the beam's color.
var rarities: Array[VersusRarity] = []
var _lid: Node3D
var _glow: MeshInstance3D
var _label: Label3D
var _beam: MeshInstance3D


func _init(p_item: VersusItem = null) -> void:
	item = p_item
	name = "VersusChest"
	collision_layer = WALLS_LAYER


func _ready() -> void:
	add_to_group(GROUP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2.0
	add_child(shape)
	add_child(_mesh(_build_trunk()))
	_lid = _mesh(_build_lid())
	_lid.position = Vector3(0, SIZE.y * 0.8, -SIZE.z / 2.0)  # Its hinge, at the back.
	add_child(_lid)
	_glow = _mesh(_build_glow())
	_glow.visible = false
	add_child(_glow)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = SIZE.y + 0.5
	_label.pixel_size = 0.003
	_label.visible = false
	add_child(_label)
	_beam = _build_beam()
	add_child(_beam)


## Seconds a hunted holds interact on it now: to open it, or to take.
func hold_time(settings: VersusSettings) -> float:
	return settings.chest_take_time if is_open else settings.chest_open_time


## Opens it (Q30): the lid, the glow, the bang heard by the boss.
func open(by: Node, settings: VersusSettings) -> void:
	if is_open:
		return
	is_open = true
	_lid.rotation.x = LID_OPEN
	_glow.visible = true
	NoiseBus.emit_noise(NoiseEvent.Type.IMPACT, global_position, settings.chest_noise_range, by)
	_show_item()
	opened.emit()


## What is in it now (what a hunted left, or null: empty).
## A client's copy (T-381): open or not, holding p_item, as the room says.
func mirror(open_now: bool, p_item: VersusItem) -> void:
	if open_now and not is_open:
		is_open = true
		_lid.rotation.x = LID_OPEN
	set_item(p_item)


func set_item(p_item: VersusItem) -> void:
	item = p_item
	_show_item()


func _show_item() -> void:
	_label.visible = is_open and item != null
	_glow.visible = is_open and item != null
	var rarity := rarity_of_item()
	_beam.visible = is_open and rarity != null
	_label.modulate = rarity.color if rarity != null else Color.WHITE
	if item != null:
		_label.text = Text.t(item.name_key)
	if rarity != null:
		(_beam.material_override as StandardMaterial3D).albedo_color = Color(rarity.color, 0.45)
		_label.text += "\n" + Text.t(rarity.name_key)


## The rarity of the gun in it, or null: no gun, or no rarities.
func rarity_of_item() -> VersusRarity:
	if item == null or item.weapon == null or rarities.is_empty():
		return null
	return rarities[clampi(item.rarity, 0, rarities.size() - 1)]


## The rarity beam: a tall unshaded column, added over what is behind it.
static func _build_beam() -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.18, BEAM_HEIGHT, 0.18)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1, 1, 1, 0.45)
	var beam := MeshInstance3D.new()
	beam.mesh = box
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = SIZE.y + BEAM_HEIGHT * 0.5
	beam.visibility_range_end = BEAM_RANGE
	beam.visible = false
	return beam


## One mesh, coloured by vertex, seen up to VISIBLE_RANGE (draw calls).
func _mesh(mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = MATERIAL
	instance.visibility_range_end = VISIBLE_RANGE
	return instance


## The trunk and its metal corners.
static func _build_trunk() -> ArrayMesh:
	var tool := BoxTool.start()
	BoxTool.box(tool, Vector3(0, SIZE.y * 0.4, 0), Vector3(SIZE.x, SIZE.y * 0.8, SIZE.z), KHAKI)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var corner := Vector3(
				x * (SIZE.x / 2.0 - 0.03), SIZE.y * 0.4, z * (SIZE.z / 2.0 - 0.03)
			)
			BoxTool.box(tool, corner, Vector3(0.08, SIZE.y * 0.82, 0.08), CORNER)
	return tool.commit()


## The lid, around its hinge.
static func _build_lid() -> ArrayMesh:
	var tool := BoxTool.start()
	BoxTool.box(tool, Vector3(0, 0.05, SIZE.z / 2.0), Vector3(SIZE.x, SIZE.y * 0.2, SIZE.z), KHAKI)
	return tool.commit()


## The red glow inside, shown while something is in it.
static func _build_glow() -> ArrayMesh:
	var tool := BoxTool.start()
	BoxTool.box(
		tool, Vector3(0, SIZE.y * 0.79, 0), Vector3(SIZE.x * 0.9, 0.02, SIZE.z * 0.85), GLOW * 3.0
	)
	return tool.commit()
