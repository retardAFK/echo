class_name MapHuntedRole
extends Node
## Solo, hunted role (S-003, Q4; S-022, T-433): wires the AI monster to the
## player, shows the hunted's HUDs, and handles a catch: the monster seizes
## the player, then the game ends (with fuse boxes, S-007) or the "caught"
## screen shows and the player starts again from a spawn, the monster back
## on patrol. GameMap adds it in solo when GameSession.role is HUNTED.

var map: GameMap


## Called by GameMap once added, before the game loop is set up.
func setup() -> void:
	map.monster.player = map.player
	map.monster.buildings = map.get_buildings()
	map.monster.player_caught.connect(_on_player_caught)
	HuntedHuds.add_own(map)
	HuntedHuds.add_network(map)


## The monster opened a hiding spot with the player inside (S-008, Q7): a
## catch, with its cry (S-012, T-145).
func found_hiding() -> void:
	MonsterNoise.scream(map.monster)
	map.monster.catch_count += 1
	_on_player_caught()


## The monster caught the player. First the catch (S-011, T-127): the monster
## seizes it, the player's head turns to its red eyes, for catch_show_time
## (2 s at most, 2.3); then the end of the game, or the "caught" screen and a
## respawn outside the game loop.
func _on_player_caught() -> void:
	var player := map.player
	var monster := map.monster
	if player.watching_catcher:
		return  # Already in its claws.
	var show := monster.settings.catch_show_time
	monster.gesture.play(MonsterBody.Action.CATCH, monster.get_body_settings().catch_time)
	monster.hold_still(show)
	player.watch_catcher(monster.get_eye_position(), show)
	await get_tree().create_timer(show, false).timeout
	_end_catch()


func _end_catch() -> void:
	if map.game_loop != null:
		map.game_loop.finish(false)  # No respawn in solo (S-007, Q5).
		return
	map.caught_screen.show_for(map.monster.settings.caught_screen_time)
	if not map.get_spawn_points().is_empty():
		map.pick_spawn()
	map.player.global_position = map.spawn
	map.player.rotation.y = map.spawn_yaw
	map.player.velocity = Vector3.ZERO
	map.monster.reset_to_patrol(map.spawn)
