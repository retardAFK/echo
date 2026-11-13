class_name DroppedFuse
extends FuseBox
## A fuse lying on the ground where a hunted was captured (S-010, T-107).
## Any hunted takes it back like from a fuse box, by holding "interact";
## GameLoop then removes it.


## Where to stand to take it: right there.
func get_approach_point() -> Vector3:
	return global_position
