extends GutTest
## The passing train covers the noises near the railway (spec S-020, T-332).

const TRAIN_SOUND := preload("res://assets/audio/ambience/train.wav")
const NEAR := Vector3(10, 0, 5)
const FAR := Vector3(10, 0, 60)

var _parent: Node3D
var _train: AmbientTrain


func before_each() -> void:
	_parent = Node3D.new()
	add_child_autofree(_parent)
	_train = AmbientTrain.new()
	_train.stream = TRAIN_SOUND
	_train.track_start = Vector3(-100, 1, 0)
	_train.track_end = Vector3(100, 1, 0)
	_train.first_wait = 1000.0
	_parent.add_child(_train)


## Puts the pass in the middle of its cover window.
func _roaring() -> void:
	_train.run_pass(true)
	_train.pass_time = _train.pass_length() / 2.0


func test_the_train_covers_only_in_the_middle_of_its_pass() -> void:
	assert_false(AmbientTrain.covers(get_tree(), NEAR), "no train")
	_train.run_pass(true)
	assert_false(_train.is_covering(), "it is still far off")
	_train.pass_time = _train.pass_length() / 2.0
	assert_true(AmbientTrain.covers(get_tree(), NEAR))
	assert_false(AmbientTrain.covers(get_tree(), FAR), "far from the railway")
	_train.pass_time = _train.pass_length() - 0.1
	assert_false(_train.is_covering(), "it is going away")


func test_a_cover_lasts_the_set_time() -> void:
	_train.run_pass(false)
	var covered := 0.0
	var step := 0.1
	while _train.pass_time >= 0.0:
		if _train.is_covering():
			covered += step
		_train._process(step)
	assert_almost_eq(covered, _train.settings.cover_time, 0.3)
	assert_eq(_train.pass_time, -1.0, "the pass is over")


func test_a_noise_near_the_railway_is_lost_for_the_monster_only() -> void:
	_roaring()
	var near := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, NEAR, 8.0)
	var far := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, FAR, 8.0)
	assert_true(near.masked, "covered by the train")
	assert_false(far.masked)
	var monster := Node3D.new()
	add_child_autofree(monster)
	assert_eq(NetGame.noise_message(near, monster, true), [], "the monster gets nothing")
	assert_false(NetGame.noise_message(far, monster, true).is_empty())


func test_no_train_no_cover() -> void:
	var noise := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, NEAR, 8.0)
	assert_false(noise.masked)


func test_online_the_room_starts_the_trains_and_tells_everyone() -> void:
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, Node3D.new())
	net.add_avatar(2, LobbyState.MONSTER_SEAT, Node3D.new())
	_parent.add_child(net)
	assert_eq(net.trains, [_train])
	assert_true(_train.auto, "the room starts trains")
	_train.run_pass(false)
	for place in [1, 2]:
		assert_has(net.sent_events, [place, [NetGame.Event.TRAIN, 0, false]])
	net.free()


func test_a_client_hears_the_train_when_the_room_says() -> void:
	var net := NetGame.new()
	_parent.add_child(net)
	assert_false(_train.auto, "a client never starts one itself")
	_train._wait = 0.0
	_train._process(0.1)
	assert_eq(_train.passes, 0)
	net.apply_event([NetGame.Event.TRAIN, 0, false])
	assert_eq(_train.passes, 1)
	assert_true(_train.playing)
	assert_eq(_train.position, _train.track_end, "from the end the room said")
	net.free()
