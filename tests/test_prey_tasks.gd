extends GutTest
## What the AI does for the objectives besides fuses (spec S-018, T-268): the
## prey reads the post-its and types the code, starts the download and lures
## the monster away, throws its relay switch; the monster switches off a
## terminal in use it sees and smashes a lit camera.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")

var _before := ""


func before_each() -> void:
	_before = OS.get_environment("ECHO_OBJECTIVES")


func after_each() -> void:
	OS.set_environment("ECHO_OBJECTIVES", _before)
	GameSession.game_seed = 0
	GameSession.role = GameSession.Role.HUNTED


## The cité in solo, the player monster (else hunted), with these objectives.
func _map(objectives: String, role := GameSession.Role.MONSTER) -> GameMap:
	OS.set_environment("ECHO_OBJECTIVES", objectives)
	GameSession.game_seed = 7
	GameSession.role = role
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	return map


func _prey(map: GameMap) -> Node3D:
	var prey: Node3D = map.prey
	prey.process_mode = Node.PROCESS_MODE_DISABLED
	return prey


func test_it_reads_the_post_its_then_types_the_code() -> void:
	var map := _map("fuse,code")
	var prey := _prey(map)
	var tasks: PreyTasks = prey.tasks
	var quests := map.game_loop.quests
	var read := 0
	while tasks.known_code == "":
		assert_eq(tasks.choose(), PreyTasks.Kind.READ)
		assert_false(tasks.arrive(), "nothing to hold at a post-it")
		read += 1
		assert_lt(read, 20, "it finds the code")
	assert_eq(tasks.known_code, quests.code)
	assert_eq(tasks.choose(), PreyTasks.Kind.KEYPAD)
	var keypad := tasks.node as Terminal
	assert_eq(keypad.kind, Terminal.Kind.CODE)
	assert_true(tasks.arrive())
	assert_eq(tasks.work_target(), keypad, "it sits first")
	keypad.sit(prey)
	assert_null(tasks.work_target())
	var over := false
	for i in 40:
		over = tasks.work(PreyTasks.KEY_TIME)
		if over:
			break
	assert_true(over)
	assert_true(map.game_loop.rules.is_done(LoopRules.Objective.CODE))
	assert_null(keypad.user, "it got up")


func test_it_starts_the_download_and_lures_the_monster_away() -> void:
	var map := _map("fuse,download")
	var prey := _prey(map)
	var tasks: PreyTasks = prey.tasks
	var quests := map.game_loop.quests
	assert_eq(tasks.choose(), PreyTasks.Kind.DOWNLOAD)
	var terminal := tasks.node as Terminal
	assert_eq(terminal, quests.download_terminal)
	assert_true(tasks.arrive())
	terminal.sit(prey)
	assert_true(tasks.work(0.1))
	assert_gte(quests.download_ratio(), 0.0, "started")
	assert_null(terminal.user, "it does not wait seated")
	var network: CityNetwork = map.get_node("Network")
	var used := network.speakers.filter(func(speaker: Loudspeaker) -> bool: return speaker.used)
	assert_eq(used.size(), 1, "one loudspeaker set off")
	var lure: Loudspeaker = used[0]
	var far := lure.global_position.distance_to(terminal.global_position)
	for speaker: Loudspeaker in network.speakers:
		assert_lte(speaker.global_position.distance_to(terminal.global_position), far + 0.01)
	assert_eq(tasks.choose(), PreyTasks.Kind.WAIT, "nothing else: it waits by the terminal")
	quests._physics_process(map.game_loop.settings.download_time + 0.1)
	assert_eq(tasks.choose(), PreyTasks.Kind.DISK, "then it fetches the disk")


func test_with_a_teammate_it_waits_for_the_other_switch() -> void:
	var map := _map("fuse,relay")
	var prey := _prey(map)
	var teammate := Node3D.new()
	teammate.add_child(CaptureState.new())
	map.add_child(teammate)
	var tasks: PreyTasks = prey.tasks
	var quests := map.game_loop.quests
	assert_eq(tasks.choose(), PreyTasks.Kind.RELAY)
	var mine := tasks.node as RelaySwitch
	var other: RelaySwitch = quests.relays[1] if quests.relays[0] == mine else quests.relays[0]
	prey.global_position = tasks.point()
	assert_true(tasks.arrive())
	assert_false(tasks.work(1.0), "a teammate may come: it waits")
	other.thrown.emit(prey)
	assert_true(tasks.work(0.1))
	assert_true(map.game_loop.rules.is_done(LoopRules.Objective.RELAY))


func test_with_a_teammate_it_throws_anyway_after_a_while() -> void:
	var map := _map("fuse,relay")
	var prey := _prey(map)
	var teammate := Node3D.new()
	teammate.add_child(CaptureState.new())
	map.add_child(teammate)
	var tasks: PreyTasks = prey.tasks
	tasks.choose()
	var mine := tasks.node as RelaySwitch
	prey.global_position = tasks.point()
	tasks.arrive()
	assert_false(tasks.work(PreyTasks.RELAY_PATIENCE * 0.5))
	assert_true(tasks.work(PreyTasks.RELAY_PATIENCE * 0.5))
	assert_true(mine.is_down)


func test_alone_it_throws_one_switch_then_runs_to_the_other() -> void:
	var map := _map("fuse,relay")
	var prey := _prey(map)
	var tasks: PreyTasks = prey.tasks
	assert_eq(tasks.choose(), PreyTasks.Kind.RELAY)
	var first := tasks.node as RelaySwitch
	prey.global_position = tasks.point()
	tasks.arrive()
	assert_true(tasks.work(0.1), "nobody to wait for")
	assert_true(first.is_down)
	assert_eq(tasks.choose(), PreyTasks.Kind.RELAY)
	var second := tasks.node as RelaySwitch
	assert_ne(second, first, "on to the other one")
	prey.global_position = tasks.point()
	tasks.arrive()
	assert_true(tasks.work(0.1))
	assert_true(map.game_loop.rules.is_done(LoopRules.Objective.RELAY))


func test_the_monster_switches_off_a_terminal_in_use_in_sight() -> void:
	var map := _map("fuse,download", GameSession.Role.HUNTED)
	await wait_physics_frames(2)
	var monster: Node3D = map.get_node("Monster")
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	var terminal := map.game_loop.quests.download_terminal
	monster.global_position = terminal.seat_point() + terminal.global_basis.z * 4.0
	await wait_physics_frames(1)
	monster._look_for_sabotage(monster.settings.sabotage_interval)
	assert_null(monster.open_target, "an idle terminal does not draw it")
	map.game_loop.quests.start_download(terminal)
	monster._sabotage_left = 0.0
	monster._look_for_sabotage(0.1)
	assert_eq(monster.open_target, terminal, "a download running does")
	for i in 100:
		terminal.hold(monster, 0.1)
		if not terminal.is_on():
			break
	assert_false(terminal.is_on(), "switched off")
	assert_true(monster._sabotage_done(terminal))
