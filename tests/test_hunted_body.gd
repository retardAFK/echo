extends GutTest
## The three hunted characters (S-011): models, animations, and which one a
## prey or another online player gets.


func test_each_look_has_its_animations() -> void:
	for look in HuntedBody.MODELS.size():
		var body := HuntedBody.new()
		body.look = look
		add_child_autofree(body)
		body.build()
		var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(player, "look %d is animated" % look)
		for name in ["Idle", "Walk", "Run", "Kneel"]:
			assert_true(player.has_animation(name), "look %d has %s" % [look, name])
		assert_eq(player.get_animation("Walk").loop_mode, Animation.LOOP_LINEAR, "the walk loops")
		assert_not_null(body.find_children("*", "Skeleton3D", true, false).front())


func test_no_model_without_a_display() -> void:
	var body := HuntedBody.new()
	add_child_autofree(body)
	# The tests run headless, like the dedicated server: nothing is built.
	assert_eq(body.get_child_count(), 0)


func test_animation_follows_speed_and_capture() -> void:
	var body := HuntedBody.new()
	assert_eq(body.get_wanted()[0], "Idle")
	body.speed = 1.5
	assert_eq(body.get_wanted()[0], "Walk")
	body.speed = 3.0
	assert_eq(body.get_wanted()[0], "Walk", "the walk speed of the hunted")
	body.speed = 5.5
	assert_eq(body.get_wanted()[0], "Run", "the sprint")
	assert_lt(body.get_wanted()[1], 1.6)
	body.down = true
	assert_eq(body.get_wanted()[0], "Kneel", "captured")
	body.free()


func test_body_plays_the_wanted_animation() -> void:
	var body := HuntedBody.new()
	add_child_autofree(body)
	body.build()
	body.speed = 5.0
	await wait_process_frames(2)
	assert_eq(body.get_animation(), &"Run")
	body.down = true
	await wait_process_frames(2)
	assert_eq(body.get_animation(), &"Kneel")


func test_changing_the_look_rebuilds() -> void:
	var body := HuntedBody.new()
	add_child_autofree(body)
	body.build()
	body.look = 2
	await wait_process_frames(1)
	var models := body.get_children().filter(
		func(node: Node) -> bool: return not node.is_queued_for_deletion()
	)
	assert_eq(models.size(), 1)


func test_online_hunted_get_a_character_and_the_monster_does_not() -> void:
	var hunted := NetPuppet.new()
	hunted.look = 1
	add_child_autofree(hunted)
	var body := hunted.get_node_or_null("Body") as HuntedBody
	assert_not_null(body)
	assert_eq(body.look, 1)
	hunted.set_down(true)
	assert_true(body.down, "captured: on its knees")
	var monster := NetPuppet.new()
	monster.kind = NetPuppet.Kind.MONSTER
	add_child_autofree(monster)
	assert_null(monster.get_node_or_null("Body"))


func test_prey_passes_its_look_and_speed() -> void:
	var prey: Prey = load("res://game/entities/prey/prey.tscn").instantiate()
	prey.look = 2
	add_child_autofree(prey)
	var body := prey.get_node("Body") as HuntedBody
	assert_eq(body.look, 2)
	prey.velocity = Vector3(3, 0, 4)
	prey._process(0.016)
	assert_almost_eq(body.speed, 5.0, 0.01)
	prey.look = 0
	assert_eq(body.look, 0)
