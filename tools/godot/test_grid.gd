class_name TestGrid
extends RefCounted
## The shared test grid (S-020, T-317, piste J2): the same five questions
## after every test game, so versions compare. simulate_games.gd fills one
## per game and prints it as a row of the table in
## specs/S-020-retours-de-test/grille-de-test.md.
##   1. Who won?
##   2. In how long?
##   3. Did a hunted get away at least once? (chases the monster lost)
##   4. Did a hiding spot save someone? (hidden while the monster came close,
##      out again without being caught)
##   5. How many catches?
## Call watch() once per physics frame.

## The monster this close to a hidden hunted: the hiding spot is put to the
## test.
const CLOSE := 5.0

var escapes := 0
var saves := 0
var catches := 0

var _chasing := false
var _tested := {}  # Hidden prey -> the monster came close.


func _init(monster: Monster) -> void:
	if monster != null:
		monster.hunted_caught.connect(func(_hunted: Node3D) -> void: catches += 1)


func watch(monster: Monster, preys: Array) -> void:
	if monster == null:
		return
	var chasing := monster.brain.state == MonsterBrain.State.CHASE
	if _chasing and not chasing:
		escapes += 1  # Catches are taken off in row().
	_chasing = chasing
	for prey: Prey in preys:
		if prey.is_hidden():
			var close := prey.global_position.distance_to(monster.global_position) < CLOSE
			_tested[prey] = _tested.get(prey, false) or close
		elif _tested.has(prey):
			if _tested[prey] and CaptureState.is_free_hunted(prey):
				saves += 1
			_tested.erase(prey)


## The row of the grid: date, commit, mode, hunted, winner, minutes,
## escapes, saves, catches.
func row(mode: String, hunted: int, winner: String, minutes: float) -> String:
	var away := maxi(escapes - catches, 0)  # A chase that ends in a catch is no escape.
	var day := Time.get_date_string_from_system()
	var output := []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
	var version: String = output[0].strip_edges() if not output.is_empty() else "?"
	return (
		"| %s | %s | %s | %d | %s | %.1f | %d | %d | %d |"
		% [day, version, mode, hunted, winner, minutes, away, saves, catches]
	)
