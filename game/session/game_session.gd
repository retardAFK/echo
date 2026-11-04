class_name GameSession
extends RefCounted
## What the player chose on the start menu (spec S-004, Q1). Kept in a static
## variable so it survives the change from the menu to the map.

enum Role { HUNTED, MONSTER }

static var role := Role.HUNTED
