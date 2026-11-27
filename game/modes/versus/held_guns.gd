class_name HeldGuns
extends Node
## The guns in the hunted's hands, seen from the third person (spec S-025,
## T-409): each hunted's body (HuntedBody) holds the model (GunModel) of the
## gun its kit has, in the color of its rarity, and puts it away when the
## kit has none. Online, the room sends each change (VersusNet.Event.GUN:
## seat, item id, rarity) and the clients put the gun in the hands of that
## seat's puppet. A child of VersusMode; remove it and nobody holds a gun.

## The guns are a bit bigger in the hands than in life, to read at a
## distance, as in an arcade shooter.
const HELD_SCALE := 1.25

var mode: VersusMode
## What each body shows: HuntedBody -> [item id, rarity].
var _shown := {}
## The room: what each seat holds, as last sent. A client: what the room
## said each seat holds (applied once its puppet is there).
var _seats := {}


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "HeldGuns"


func _process(_delta: float) -> void:
	for kit in mode.hunters:
		var weapon := kit.loadout.weapon
		var id := weapon.id if weapon != null else &""
		var rarity := weapon.rarity if weapon != null else 0
		show_on(body_of(kit.body), id, rarity)
		if mode.link != null and not mode.mirror:
			_send_if_changed(mode.link.seat_of(kit.body), id, rarity)
	if mode.mirror and mode.net != null:
		for seat: int in _seats:
			var puppet := mode.net.puppets.get(seat) as NetPuppet
			if puppet != null:
				show_on(puppet.hunted_body(), _seats[seat][0], _seats[seat][1])


## The HuntedBody that shows body (a Prey's, or the player's own in the
## third person), or null.
static func body_of(body: Node) -> HuntedBody:
	if body == null:
		return null
	for child in body.get_children():
		if child is HuntedBody:
			return child
	return null


## Puts the gun of item id (its rarity) in shown's hands, if it changed.
func show_on(shown: HuntedBody, id: StringName, rarity: int) -> void:
	if shown == null or _shown.get(shown, []) == [id, rarity]:
		return
	_shown[shown] = [id, rarity]
	var gun: Node3D = null
	if id != &"":
		var item := mode.item(id, rarity)
		var glow := ViewModel.SMG_GLOW
		var tier := VersusRarity.of(item, mode.settings.rarities)
		if tier != null and rarity > 0:
			glow = tier.color
		gun = GunModel.instance(id, glow)
		if gun != null:
			gun.scale = Vector3.ONE * HELD_SCALE
	shown.hold(gun, GunModel.fore_grip(id))


## A client: the room says what seat holds.
func apply(seat: int, id: String, rarity: int) -> void:
	_seats[seat] = [StringName(id), rarity]


## The room: one event for each seat holding a gun, for a player who joins.
func events() -> Array:
	var all := []
	for seat: int in _seats:
		all.append([VersusNet.Event.GUN, seat, String(_seats[seat][0]), _seats[seat][1]])
	return all


func _send_if_changed(seat: int, id: StringName, rarity: int) -> void:
	if seat < 0 or _seats.get(seat, []) == [id, rarity]:
		return
	_seats[seat] = [id, rarity]
	mode.link.send([VersusNet.Event.GUN, seat, String(id), rarity])
