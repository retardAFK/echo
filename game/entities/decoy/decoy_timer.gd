class_name DecoyTimer
extends RefCounted
## The clockwork of an alarm clock decoy (spec S-008, Q3), pure logic: it
## ticks for decoy_delay, then rings for decoy_ring_time with a noise every
## decoy_noise_interval, then it is done. Crushed by the monster (Q4), it is
## done at once.

enum State { TICKING, RINGING, DONE }

var settings: RuseSettings
var state := State.TICKING

var _left := 0.0
var _noise_left := 0.0


func _init(p_settings: RuseSettings) -> void:
	settings = p_settings
	_left = settings.decoy_delay


## One step of time. Returns whether a ringing noise is due now.
func update(delta: float) -> bool:
	match state:
		State.TICKING:
			_left -= delta
			if _left <= 0.0:
				state = State.RINGING
				_left = settings.decoy_ring_time
				_noise_left = settings.decoy_noise_interval
				return true
		State.RINGING:
			_left -= delta
			if _left <= 0.0:
				state = State.DONE
				return false
			_noise_left -= delta
			if _noise_left <= 0.0:
				_noise_left += settings.decoy_noise_interval
				return true
	return false


## Stops it for good. Returns whether it was still ticking or ringing.
func crush() -> bool:
	if state == State.DONE:
		return false
	state = State.DONE
	return true
