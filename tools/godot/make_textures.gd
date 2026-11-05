extends SceneTree
## Generates the greybox's pixel textures (spec S-005, T-030).
## Run: godot --headless -s tools/godot/make_textures.gd
## Same seed, same pixels: the PNGs can be regenerated at any time.

const OUT_DIR := "res://assets/textures/"
## 128 px over 2 m: 64 px per meter (constitution 2.3).
const SIZE := 128
## Concrete panels of 2 m, so one seam per texture repeat.
const SEAM := SIZE
const SEED := 7


func _initialize() -> void:
	_save(_concrete(), "concrete_wall.png")
	_save(_asphalt(), "asphalt_floor.png")
	quit()


func _save(img: Image, file: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR + file)
	img.save_png(path)
	print("wrote ", path)


func _concrete() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := 0.62 + rng.randf_range(-0.06, 0.06)
			# Large soft stains from two low frequency waves.
			v -= 0.05 * (sin(x * 0.11 + y * 0.05) + cos(y * 0.09 - x * 0.03))
			# Panel seams and the formwork holes of cast concrete.
			if y % SEAM == 0 or x % SEAM == 0:
				v -= 0.2
			elif x % (SEAM / 2) == SEAM / 4 and y % (SEAM / 2) == SEAM / 4:
				v -= 0.25
			# Rain streaks running down from the seams.
			if x % 23 < 2 and (y % SEAM) < 20 + (x * 7) % 25:
				v -= 0.06
			if rng.randf() < 0.02:
				v -= 0.15
			img.set_pixel(x, y, Color(v, v, v * 0.97))
	return img


func _asphalt() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := 0.4 + rng.randf_range(-0.07, 0.07)
			if rng.randf() < 0.05:
				v += 0.12  # Pale gravel.
			# A crack wandering across the tile.
			var crack_y := int(SIZE * 0.6 + 10.0 * sin(x * 0.08) + 4.0 * sin(x * 0.31))
			if absi(y - crack_y) < 1 and x > SIZE / 5:
				v -= 0.22
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	return img
