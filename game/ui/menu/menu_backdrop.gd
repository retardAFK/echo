class_name MenuBackdrop
extends Control
## Background of a menu screen (spec S-013, Q2, T-162): a view of the cité
## captured in the game, under a dark shade on the left so the text stays
## readable. The image is set on this root, never on the child of an
## instance (PR #31).

@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_image.texture = value
## How dark the shade gets, 0 for none (the pause shows the game instead).
@export_range(0.0, 1.0, 0.05) var shade := 1.0:
	set(value):
		shade = value
		if is_node_ready():
			_shade.modulate.a = value

@onready var _image: TextureRect = $Image
@onready var _shade: TextureRect = $Shade


func _ready() -> void:
	_image.texture = background
	_shade.modulate.a = shade
