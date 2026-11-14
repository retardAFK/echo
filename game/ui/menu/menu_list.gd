class_name MenuList
extends VBoxContainer
## A column of menu entries (spec S-013, T-162), built from translation keys.
## Up and down go round, Enter or a click chooses.

## An entry was chosen, by its translation key.
signal chosen(key: String)

## Translation keys of the entries, top to bottom.
@export var keys: PackedStringArray = []:
	set(value):
		keys = value
		if is_node_ready():
			_build()
## Smaller entries, for menus beside other content.
@export var small := false

var _items: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	_build()


func item(key: String) -> MenuItem:
	return _items.get(key)


## Shows or hides an entry, keeping the round trip of the focus right.
func set_item_visible(key: String, shown: bool) -> void:
	var entry := item(key)
	if entry != null:
		entry.visible = shown
		_link_focus()


## Gives the focus to the first shown entry.
func focus_first() -> void:
	var shown := _shown()
	if not shown.is_empty():
		shown[0].grab_focus()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_items.clear()
	for key in keys:
		var entry := MenuItem.new()
		entry.key = key
		entry.name = key
		if small:
			entry.theme_type_variation = &"SmallMenuItem"
		entry.pressed.connect(func() -> void: chosen.emit(key))
		add_child(entry)
		_items[key] = entry
	_link_focus()


func _shown() -> Array[MenuItem]:
	var shown: Array[MenuItem] = []
	for key in keys:
		var entry: MenuItem = _items.get(key)
		if entry != null and entry.visible:
			shown.append(entry)
	return shown


func _link_focus() -> void:
	var shown := _shown()
	for index in shown.size():
		var entry := shown[index]
		var above := shown[(index - 1 + shown.size()) % shown.size()]
		var below := shown[(index + 1) % shown.size()]
		entry.focus_neighbor_top = entry.get_path_to(above)
		entry.focus_neighbor_bottom = entry.get_path_to(below)
		entry.focus_previous = entry.focus_neighbor_top
		entry.focus_next = entry.focus_neighbor_bottom
