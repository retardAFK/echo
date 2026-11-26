class_name Stamina
extends RefCounted
## The hunted's stamina in the Versus mode (spec S-024, Q15, T-371): running
## and the dodge roll spend it, it refills after a short pause. Pure.

var settings: VersusSettings
## 0 to 1.
var value := 1.0
var _rest := 0.0


func _init(versus: VersusSettings) -> void:
	settings = versus


## Spends share (0 to 1) if there is enough; true if spent.
func spend(share: float) -> bool:
	if value < share:
		return false
	value -= share
	_rest = settings.stamina_refill_delay
	return true


## Spends what running for delta seconds costs; false once empty.
func run(delta: float) -> bool:
	if value <= 0.0:
		return false
	value = maxf(value - settings.run_cost * delta, 0.0)
	_rest = settings.stamina_refill_delay
	return true


func update(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		return
	value = minf(value + delta / settings.stamina_refill_time, 1.0)
