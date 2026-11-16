extends GutHookScript
## Before the tests: the games of the cité have three fuses, as the tests of
## the loop (S-007) expect. test_objectives.gd draws or imposes the other
## objectives of S-018 itself.

const OBJECTIVES := "fuse,fuse,fuse"


func run() -> void:
	OS.set_environment("ECHO_OBJECTIVES", OBJECTIVES)
