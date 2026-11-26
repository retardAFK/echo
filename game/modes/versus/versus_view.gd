class_name VersusView
extends Node
## The Versus seen from behind one's own character (spec S-025, Q1, T-402):
## a camera on a spring arm over the shoulder, which comes closer instead of
## going through a wall, and the character's own body (a HuntedBody, or the
## MonsterBody of the boss) shown and animated. V switches back to the first
## person (the arms of ViewModel) and again.
## The shot goes where the crosshair (the middle of the screen) points:
## aim_direction casts the camera's ray, then aims from the eyes to what it
## meets. The room computes the same from the player's yaw and pitch, so a
## shot lands at the same place here and online.

const HUNTED_BODY := preload("res://game/entities/hunted_body/hunted_body.tscn")
const MONSTER_BODY := preload("res://game/entities/monster_body/monster_body.tscn")
## Physics layers 1 and 2, the ground and the walls: what the arm and the
## aim ray stop on.
const WORLD_LAYERS := 1 | 2

var settings: VersusSettings
## The avatar seen: a Player or a MonsterAvatar.
var avatar: CharacterBody3D
var first_person := false
var camera: Camera3D
var arm: SpringArm3D
var _own_camera: Camera3D
var _hunted_body: HuntedBody
var _monster_body: MonsterBody
## How hard the camera shakes now (0 to 1), after a shot (S-025, T-403).
var _shake := 0.0


func _init(p_settings: VersusSettings, p_avatar: CharacterBody3D) -> void:
	settings = p_settings
	avatar = p_avatar
	name = "VersusView"


func _ready() -> void:
	var head: Node3D = avatar.get_node("Head")
	_own_camera = head.get_node("Camera3D")
	arm = SpringArm3D.new()
	arm.name = "ShoulderArm"
	arm.position = shoulder(avatar)
	arm.spring_length = arm_length(settings, avatar)
	arm.collision_mask = WORLD_LAYERS
	arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	arm.add_excluded_object(avatar.get_rid())
	head.add_child(arm)
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = _own_camera.fov
	camera.near = _own_camera.near
	camera.far = _own_camera.far
	arm.add_child(camera)
	_add_body()
	_apply()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_V:
		first_person = not first_person
		_apply()


## Shakes the camera a little (a shot's kick, S-025): amount from 0 to 1.
func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 6.0)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.06
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.06
	if first_person:
		return
	var speed := Vector2(avatar.velocity.x, avatar.velocity.z).length()
	if _hunted_body != null:
		var player := avatar as Player
		var kit := avatar.get_node_or_null("HunterKit") as HunterKit
		var down := kit != null and not kit.vitals.is_standing()
		_hunted_body.show_state(player.get_gait(), speed, down, player.get_gesture())
	if _monster_body != null:
		_monster_body.show_state(speed, (avatar as MonsterAvatar).body_action)


## Where the arm starts, from the head: over the right shoulder.
static func shoulder(body: Node3D) -> Vector3:
	return Vector3(0.55, 0.25, 0.0) if body is Player else Vector3(0.8, 0.6, 0.0)


## How far behind the head the camera sits: farther for the big boss.
static func arm_length(values: VersusSettings, body: Node3D) -> float:
	return values.view_distance if body is Player else values.boss_view_distance


## Where a shot from eye goes for a player looking along look (a basis from
## its yaw and pitch): to what the camera's ray meets, else far ahead. The
## same here and on the room (the arm's give against walls left aside).
static func aim_direction(
	body: CharacterBody3D, eye: Vector3, look: Basis, values: VersusSettings
) -> Vector3:
	var forward := -look.z
	var from := eye + look * shoulder(body) + look.z * arm_length(values, body)
	var to := from + forward * values.aim_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYERS | 1 << 3)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", to)
	if (target - from).dot(forward) < (eye - from).dot(forward) + 0.5:
		return forward  # Something between the camera and the eyes: straight on.
	return (target - eye).normalized()


func _add_body() -> void:
	if avatar is Player:
		_hunted_body = HUNTED_BODY.instantiate()
		_hunted_body.role = HuntedBody.role_for_seat(maxi(GameSession.online_seat, 1))
		avatar.add_child(_hunted_body)
	elif avatar is MonsterAvatar:
		var placeholder := avatar.get_node_or_null("Body") as Node3D
		if placeholder != null:
			placeholder.visible = false
		_monster_body = MONSTER_BODY.instantiate()
		avatar.add_child(_monster_body)


## The camera and the body for the current view.
func _apply() -> void:
	(_own_camera if first_person else camera).make_current()
	if _hunted_body != null:
		_hunted_body.visible = not first_person
	if _monster_body != null:
		_monster_body.visible = not first_person
