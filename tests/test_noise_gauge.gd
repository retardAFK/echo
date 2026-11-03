extends GutTest
## Player noise gauge in the HUD (spec S-002, T-012).

const GAUGE_SCENE := preload("res://game/ui/noise_gauge.tscn")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const EPSILON := 0.001

var _gauge: NoiseGauge
var _player: Node3D
var _settings: NoiseSettings = NoiseBus.settings


func before_each() -> void:
	_player = Node3D.new()
	add_child_autofree(_player)
	_gauge = GAUGE_SCENE.instantiate()
	_gauge.player = _player
	add_child_autofree(_gauge)


func _step(noise_range: float, source: Node = _player) -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, noise_range, source)


func _fill_width() -> float:
	return _gauge.get_node("Bar/Fill").size.x


func test_starts_empty() -> void:
	assert_eq(_gauge.level, 0.0)
	assert_eq(_fill_width(), 0.0)


func test_levels_per_gait_match_spec() -> void:
	_step(_settings.sprint_range)
	assert_between(_gauge.level, 9.0, 9.5, "sprint about 9")
	_gauge.level = 0.0
	_step(_settings.walk_range)
	assert_between(_gauge.level, 2.5, 3.0, "walk about 3")
	_gauge.level = 0.0
	_step(_settings.crouch_range)
	assert_true(_gauge.level <= 1.0, "crouch at most 1")


func test_fill_follows_level() -> void:
	_step(_settings.gauge_full_range)
	var bar_width: float = _gauge.get_node("Bar").size.x
	assert_almost_eq(_fill_width(), bar_width, EPSILON)
	assert_eq(_gauge.get_node("Bar/Fill").color, _settings.noise_color)


func test_ignores_other_sources() -> void:
	_step(_settings.sprint_range, null)
	var other := Node3D.new()
	add_child_autofree(other)
	_step(_settings.sprint_range, other)
	assert_eq(_gauge.level, 0.0)


func test_quiet_step_does_not_lower_gauge() -> void:
	_step(_settings.sprint_range)
	var loud := _gauge.level
	_step(_settings.crouch_range)
	assert_almost_eq(_gauge.level, loud, EPSILON)


func test_decays_to_zero_in_decay_time() -> void:
	_step(_settings.gauge_full_range)
	_gauge._process(_settings.gauge_decay_time / 2.0)
	assert_almost_eq(_gauge.level, NoiseMath.GAUGE_MAX / 2.0, EPSILON)
	_gauge._process(_settings.gauge_decay_time / 2.0)
	assert_eq(_gauge.level, 0.0)
	assert_eq(_fill_width(), 0.0)


func test_label_is_translated() -> void:
	var label: Label = _gauge.get_node("Label")
	assert_eq(label.text, "HUD_NOISE")
	TranslationServer.set_locale("fr")
	assert_eq(tr("HUD_NOISE"), "Bruit")


func test_greybox_gauge_follows_player() -> void:
	var map: Node = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var gauge: NoiseGauge = map.get_node("NoiseGauge")
	assert_eq(gauge.player, map.get_node("Player"))
