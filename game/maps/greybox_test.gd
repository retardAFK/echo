extends Node3D
## Greybox test map (specs S-001 to S-003): wires the monster to the player and
## handles a catch (Q4 of S-003): "caught" screen, player back to the start,
## monster back on patrol far from the player.

@onready var _player: Player = $Player
@onready var _monster: Monster = $Monster
@onready var _caught_screen: CaughtScreen = $CaughtScreen
@onready var _spawn: Vector3 = _player.global_position


func _ready() -> void:
	_monster.player = _player
	_monster.player_caught.connect(_on_player_caught)


func _on_player_caught() -> void:
	_caught_screen.show_for(_monster.settings.caught_screen_time)
	_player.global_position = _spawn
	_player.velocity = Vector3.ZERO
	_monster.reset_to_patrol(_spawn)
