class_name Interactable
extends RefCounted
## What the hunted can use with the "interact" action (specs S-006 to S-008):
## car alarms, fuse boxes, the transformer, pickups, hiding spots. Each one is
## in this group and has can_interact(from), get_prompt() and interact(user),
## or hold(user, delta) for the ones held down (HoldInteraction).

const GROUP := &"interactable"
