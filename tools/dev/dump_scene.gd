extends Node
## Canonical text dump of a packed scene (S-022, T-432): every node, its
## stored properties and groups, without internal ids, so two builds of the
## cité can be compared with diff even though the binary .scn differs.
## Run as a scene, so the autoloads the game scripts use are loaded:
##   godot --headless tools/dev/dump_scene.tscn -- res://path.scn out.txt

const SKIPPED := [
	"resource_local_to_scene", "resource_name", "resource_path", "resource_scene_unique_id"
]

var out: FileAccess


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: PackedScene = load(args[0])
	out = FileAccess.open(args[1], FileAccess.WRITE)
	var root := scene.instantiate()
	_dump(root, root)
	out.close()
	get_tree().quit()


func _val(v: Variant, depth: int) -> String:
	if v is Resource:
		return _resource(v, depth)
	if v is Array:
		var a: Array[String] = []
		for e in v:
			a.append(_val(e, depth + 1))
		return "[" + ", ".join(a) + "]"
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.sort()
		var d: Array[String] = []
		for k in keys:
			d.append("%s:%s" % [k, _val(v[k], depth + 1)])
		return "<" + ", ".join(d) + ">"
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return "%s(%d,%s)" % [type_string(typeof(v)), v.size(), str(hash(v))]
	return str(v)


func _resource(r: Resource, depth: int) -> String:
	if depth > 3:
		return "<res %s>" % r.get_class()
	if r.resource_path != "" and not r.resource_path.contains("::"):
		return "<res %s>" % r.resource_path
	var parts: Array[String] = [r.get_class()]
	for p in r.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and p.name not in SKIPPED:
			parts.append("%s=%s" % [p.name, _val(r.get(p.name), depth + 1)])
	return "{" + ", ".join(parts) + "}"


func _dump(node: Node, root: Node) -> void:
	var line := "%s %s" % [root.get_path_to(node), node.get_class()]
	for p in node.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			line += " | %s=%s" % [p.name, _val(node.get(p.name), 0)]
	line += " | groups=%s" % str(node.get_groups())
	out.store_line(line)
	for c in node.get_children():
		_dump(c, root)
