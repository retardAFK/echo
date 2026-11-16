class_name FloppyDisk
extends FuseBox
## The floppy disk of a finished download (spec S-018, Q13), lying by its
## terminal, or where the hunted carrying it was captured. Taken like a fuse,
## by holding "interact" (fuse_taken), it goes to the transformer.


func get_prompt() -> String:
	return "HUD_INTERACT_DISK" if has_fuse else ""


## Where to stand to take it: right there.
func get_approach_point() -> Vector3:
	return global_position
