class_name GameSession
extends RefCounted
## What the player chose on the start menu (spec S-004, Q1). Kept in a static
## variable so it survives the change from the menu to the map.

enum Role { HUNTED, MONSTER }

static var role := Role.HUNTED

## Seed of the next game (spawn, fuses, decoys), 0 for a new draw each time.
## The bench mode (S-009, T-075) fixes it so every run plays the same game.
static var game_seed := 0
