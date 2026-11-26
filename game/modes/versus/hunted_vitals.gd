class_name HuntedVitals
extends RefCounted
## A hunted's health in the Versus mode (spec S-024, Q5 and Q14, T-371):
## hit points, downed, revived, finished, out. Pure; the hunted's node holds
## one and calls update() each frame.

signal downed
signal revived
signal out

enum State { STANDING, DOWN, OUT }

var settings: VersusSettings
var health := 0
var state := State.STANDING
## Revives still possible (Q5).
var revives_left := 0
## Seconds left before a downed hunted is out (Q5).
var down_left := 0.0
## Seconds still unhurtable (the dodge roll, Q15).
var shield_left := 0.0


func _init(versus: VersusSettings) -> void:
	settings = versus
	health = versus.hunted_health
	revives_left = versus.revives


func is_standing() -> bool:
	return state == State.STANDING


func is_down() -> bool:
	return state == State.DOWN


func is_out() -> bool:
	return state == State.OUT


## Takes damage hit points; true if it was hurt.
func hurt(damage: int) -> bool:
	if not is_standing() or shield_left > 0.0 or damage <= 0:
		return false
	health = maxi(health - damage, 0)
	if health == 0:
		state = State.DOWN
		down_left = settings.down_time
		downed.emit()
	return true


## A teammate revived it (Q5): back up, or out after its last revive.
func revive() -> bool:
	if not is_down():
		return false
	if revives_left <= 0:
		_go_out()
		return false
	revives_left -= 1
	health = settings.revive_health
	state = State.STANDING
	revived.emit()
	return true


## The boss finished it (Q5).
func finish() -> void:
	if is_down():
		_go_out()


## Unhurtable for seconds (the dodge roll).
func shield(seconds: float) -> void:
	shield_left = maxf(shield_left, seconds)


func update(delta: float) -> void:
	shield_left = maxf(shield_left - delta, 0.0)
	if is_down():
		down_left = maxf(down_left - delta, 0.0)
		if down_left <= 0.0:
			_go_out()


func _go_out() -> void:
	state = State.OUT
	health = 0
	out.emit()
