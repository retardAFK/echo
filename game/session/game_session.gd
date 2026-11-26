class_name GameSession
extends RefCounted
## What the player chose on the start menu (spec S-004, Q1). Kept in a static
## variable so it survives the change from the menu to the map.

enum Role { HUNTED, MONSTER }

static var role := Role.HUNTED

## The game mode (spec S-024, T-374): &"hunt" (the Traque, the game as it
## was) or the name of a mode module of game/modes/ (&"versus").
static var mode := &"hunt"

## Seed of the next game (spawn, fuses, decoys), 0 for a new draw each time.
## The bench mode (S-009, T-075) fixes it so every run plays the same game.
static var game_seed := 0

## Online game (S-010, T-097): this player's seat, LobbyState.MONSTER_SEAT for
## the monster, 1 to 3 for the hunted; -1 when playing alone.
static var online_seat := -1
## Online game, room side: the seats as the leader launched them.
static var online_lobby: LobbyState
