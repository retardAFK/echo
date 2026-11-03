class_name NoiseGauge
extends CanvasLayer
## Player noise gauge (spec S-002, T-012): jumps to the level of the player's
## last noise, then decays back to zero. Bottom left, always visible.

@export var player: Node

var settings: NoiseSettings = NoiseBus.settings
var level := 0.0

@onready var _bar: ColorRect = $Bar
@onready var _fill: ColorRect = $Bar/Fill


func _ready() -> void:
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	_fill.color = settings.noise_color
	_refresh()


func _process(delta: float) -> void:
	if level > 0.0:
		level = NoiseMath.decay_gauge(level, delta, settings)
		_refresh()


func _on_noise_emitted(event: NoiseEvent) -> void:
	if player == null or event.source != player:
		return
	level = maxf(level, NoiseMath.gauge_level(event.noise_range, settings))
	_refresh()


func _refresh() -> void:
	_fill.size.x = _bar.size.x * level / NoiseMath.GAUGE_MAX
