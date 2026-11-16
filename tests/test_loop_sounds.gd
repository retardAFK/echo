extends GutTest
## Sounds of the game loop (spec S-007, T-059).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const BOX_SCENE := preload("res://game/entities/fuse_box/fuse_box.tscn")


func test_the_hum_loops_and_the_others_play_once() -> void:
	var dir := "res://assets/audio/loop/"
	var hum: AudioStreamWAV = load(dir + "transformer_hum.wav")
	assert_eq(hum.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	for file in ["fuse_clank.wav", "repair_sparks.wav", "siren.wav"]:
		var stream: AudioStreamWAV = load(dir + file)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, file)
	var siren: AudioStreamWAV = load(dir + "siren.wav")
	assert_almost_eq(siren.get_length(), 10.0, 0.05, "as long as the siren (Q4)")


func test_a_fuse_box_clanks() -> void:
	var box: FuseBox = BOX_SCENE.instantiate()
	add_child_autofree(box)
	box.set_fuse(true)
	box.hold(self, 0.1)
	assert_true(box.get_node("Clank").playing)


func test_the_transformer_sparks_hums_and_wails() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var loop := map.game_loop
	var transformer := loop.transformer
	var player: Node = map.get_node("Player")
	loop.rules.carried = 3
	transformer.hold(player, 0.1)
	assert_true(transformer.get_node("Sparks").playing)
	assert_false(transformer.is_humming())
	for i in 3:
		transformer.hold(player, 4.1)
	assert_true(transformer.is_humming(), "repaired, it hums")
	assert_true(transformer.get_node("Siren").playing, "the siren wails")


func test_the_ears_leave_self_voiced_noises_to_their_makers() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var player: Player = map.get_node("Player")
	var is_ears := func(node: Node) -> bool: return node is PlayerEars
	var ears: PlayerEars = player.find_children("*", "Node3D").filter(is_ears)[0]
	var at := player.get_eye_position() + Vector3(1, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FUSE, at, 3.0, null)
	NoiseBus.emit_noise(NoiseEvent.Type.SIREN, at, 300.0, null)
	assert_eq(ears.heard_count, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, at, 4.0, null)
	assert_eq(ears.heard_count, 1)
