extends GutTest
## The scan gauge (spec S-004, Q3, D-009, T-023).

var _settings := MonsterSettings.new()
var _gauge: ScanGauge


func before_each() -> void:
	_gauge = ScanGauge.new(_settings)


func _run(seconds: float, step := 0.1) -> void:
	for i in roundi(seconds / step):
		_gauge.update(step)


func test_starts_full_with_eight_seconds() -> void:
	assert_eq(_settings.scan_capacity, 8.0)
	assert_eq(_gauge.get_ratio(), 1.0)


func test_listens_after_one_second_of_focus() -> void:
	assert_true(_gauge.start())
	_run(0.9)
	assert_false(_gauge.is_listening())
	_run(0.2)
	assert_true(_gauge.is_listening())


func test_full_gauge_lasts_eight_seconds() -> void:
	_gauge.start()
	_run(7.9)
	assert_true(_gauge.active)
	_run(0.2)
	assert_false(_gauge.active, "an empty gauge ends the scan")
	assert_eq(_gauge.level, 0.0)


func test_recharges_fully_in_forty_five_seconds() -> void:
	_gauge.level = 0.0
	_run(22.5)
	assert_almost_eq(_gauge.get_ratio(), 0.5, 0.01)
	_run(23.0)
	assert_eq(_gauge.get_ratio(), 1.0)


func test_cannot_start_below_a_quarter() -> void:
	_gauge.level = _settings.scan_capacity * 0.2
	assert_false(_gauge.start())
	_gauge.level = _settings.scan_capacity * 0.25
	assert_true(_gauge.start())


func test_does_not_recharge_while_scanning() -> void:
	_gauge.start()
	_run(2.0)
	_gauge.stop()
	var after_scan := _gauge.level
	assert_almost_eq(after_scan, 6.0, 0.01)
	_run(4.5)
	assert_almost_eq(_gauge.level, after_scan + 4.5 * 8.0 / 45.0, 0.01)
