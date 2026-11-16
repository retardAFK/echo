extends SceneTree
## Generates the atlas of the HLM interior linings (S-019, validated mood board
## tools/blender/hlm_interior_mood.py) and of the hospital (S-014, mood board
## tools/blender/hospital_mood.py): one tile per kind of wall, floor and
## ceiling, 4 m wide and one storey (3 m) high at 64 px per meter.
## Run: godot --headless -s tools/godot/make_interior_atlas.gd
## Same seed, same pixels: the PNG can be regenerated at any time.
##
## The lining material maps the world triplanarly with uv_scale (1/4, 1/3, 1/4),
## so a tile row is a height above the storey floor: row 0 is the floor line.
## Dull colors only, never orange (constitution 2.3).

const OUT := "res://assets/textures/interior_atlas.png"
const TILE := Vector2i(256, 192)
const GRID := Vector2i(4, 4)
const PPM := 64.0
const SEED := 19

## Tile indices, kept in step with InteriorLining.Tile.
enum Tile {
	HALL, STAIRS, CORRIDOR, LIVING, BEDROOM, KITCHEN, CELLAR, CEILING,
	TERRAZZO, LINO, PARQUET, CONCRETE,
	WARD_CORRIDOR, FAIENCE, WARD, WARD_LINO,
}

var _rng := RandomNumberGenerator.new()
var _img: Image
var _origin := Vector2i.ZERO


func _initialize() -> void:
	_rng.seed = SEED
	_img = Image.create(TILE.x * GRID.x, TILE.y * GRID.y, false, Image.FORMAT_RGB8)
	for tile in Tile.values():
		_origin = Vector2i(tile % GRID.x, tile / GRID.x) * TILE
		call("_" + str(Tile.keys()[tile]).to_lower())
	var error := _img.save_png(ProjectSettings.globalize_path(OUT))
	print("wrote ", OUT, " error ", error)
	quit(error)


# --- Pixel helpers (x across the tile, y = height above the floor) ---------


func _put(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= TILE.x or y >= TILE.y:
		return
	_img.set_pixel(_origin.x + x, _origin.y + y, c.clamp())


func _pick(x: int, y: int) -> Color:
	return _img.get_pixel(_origin.x + posmod(x, TILE.x), _origin.y + posmod(y, TILE.y))


func _noise(c: Color, spread: float) -> Color:
	var n := _rng.randf_range(-spread, spread)
	return Color(c.r + n, c.g + n, c.b + n)


func _fill(y0: int, y1: int, base: Color, spread: float) -> void:
	for y in range(y0, y1):
		for x in TILE.x:
			_put(x, y, _noise(base, spread))


func _line(y0: int, y1: int, c: Color) -> void:
	for y in range(y0, y1):
		for x in TILE.x:
			_put(x, y, _noise(c, 0.01))


## Ceramic tiles of size px from y0 to y1, some cracked or missing.
func _tiles(y0: int, y1: int, size: int, base: Color, grout: Color, dirt: float) -> void:
	var tones := {}
	for y in range(y0, y1):
		for x in TILE.x:
			if x % size == 0 or (y - y0) % size == 0:
				_put(x, y, _noise(grout, 0.02))
				continue
			var cell := Vector2i(x / size, (y - y0) / size)
			if not tones.has(cell):
				tones[cell] = _rng.randf_range(-0.04, 0.03)
				if _rng.randf() < 0.04:
					tones[cell] = -0.3  # A missing tile, the glue showing.
			var t: float = tones[cell]
			_put(x, y, _noise(Color(base.r + t, base.g + t, base.b + t), dirt))


## Darkens soft round patches, more of them near the floor.
func _stains(count: int, strength: float, color: Color, low: bool) -> void:
	for i in count:
		var cx := _rng.randi_range(0, TILE.x - 1)
		var cy := _rng.randi_range(0, TILE.y / 3) if low else _rng.randi_range(0, TILE.y - 1)
		var r := _rng.randf_range(6, 22)
		for y in range(int(cy - r), int(cy + r)):
			for x in range(int(cx - r), int(cx + r)):
				var d := Vector2(x - cx, (y - cy) * 1.4).length()
				if d < r:
					var c := _pick(x, y)
					_put_wrap(x, y, c.lerp(color, strength * (1.0 - d / r)))


func _put_wrap(x: int, y: int, c: Color) -> void:
	if y < 0 or y >= TILE.y:
		return
	_put(posmod(x, TILE.x), y, c)


## Run-off streaks down from the top, and the dirty band of the floor.
func _grime(top_streaks: int, floor_band: int) -> void:
	for i in top_streaks:
		var x := _rng.randi_range(0, TILE.x - 1)
		var y0 := TILE.y - 1 - _rng.randi_range(0, 10)
		var length := _rng.randi_range(20, 90)
		for dy in length:
			_put(x, y0 - dy, _pick(x, y0 - dy).darkened(0.18 * (1.0 - float(dy) / length)))
	for y in floor_band:
		for x in TILE.x:
			_put(x, y, _pick(x, y).darkened(0.35 * (1.0 - float(y) / floor_band)))


## Scribbled tags between heights y0 and y1, in dull colors.
func _tags(count: int, y0: int, y1: int) -> void:
	var inks := [Color(0.05, 0.05, 0.06), Color(0.05, 0.05, 0.06), Color(0.12, 0.16, 0.34), Color(0.36, 0.07, 0.08), Color(0.62, 0.62, 0.58)]
	for i in count:
		var ink: Color = inks[_rng.randi_range(0, inks.size() - 1)]
		var p := Vector2(_rng.randf_range(0, TILE.x), _rng.randf_range(y0, y1))
		var heading := _rng.randf_range(-0.4, 0.4)
		for step in _rng.randi_range(60, 140):
			heading += _rng.randf_range(-1.2, 1.2)
			p += Vector2(cos(heading) * 1.3, sin(heading) * 1.0)
			p.y = clampf(p.y, y0, y1)
			_put_wrap(int(p.x), int(p.y), ink)
			_put_wrap(int(p.x) + 1, int(p.y), ink)


## Wallpaper: stripes, a small motif, nicotine towards the ceiling, torn
## patches showing the plaster, a wooden skirting board.
func _wallpaper(base: Color, motif: Color, stripe: int, tears: int) -> void:
	for y in TILE.y:
		var yellow := 0.1 * float(y) / TILE.y
		for x in TILE.x:
			var c := base
			if x % stripe < 2:
				c = base.darkened(0.12)
			var m := Vector2i(x % stripe, y % stripe) - Vector2i(stripe / 2, stripe / 2)
			if m.length_squared() <= 3:
				c = motif
			c = Color(c.r, c.g - yellow * 0.3, c.b - yellow)
			_put(x, y, _noise(c, 0.02))
	for i in tears:
		# A ragged strip torn off from the top: grey plaster, a darker edge.
		var cx := _rng.randi_range(0, TILE.x - 1)
		var w := _rng.randi_range(4, 12)
		var bottom := _rng.randi_range(70, 150)
		for y in range(bottom, TILE.y):
			var half := w + _rng.randi_range(-2, 2)
			for x in range(cx - half, cx + half):
				var plaster := Color(0.38, 0.37, 0.33)
				var edge := absi(x - cx) >= half - 1 or y == bottom
				_put_wrap(x, y, _noise(base.darkened(0.25) if edge else plaster, 0.02))
	_stains(6, 0.35, Color(0.24, 0.2, 0.12), false)
	_line(0, 6, Color(0.2, 0.13, 0.08))
	_line(6, 7, Color(0.1, 0.07, 0.05))


# --- Tiles -------------------------------------------------------------------


## Entrance hall: beige faience to 1.5 m, pale green paint above, tags.
func _hall() -> void:
	var split := int(1.5 * PPM)
	_tiles(0, split, 16, Color(0.52, 0.48, 0.4), Color(0.27, 0.25, 0.21), 0.03)
	_line(split, split + 3, Color(0.08, 0.08, 0.08))
	_fill(split + 3, TILE.y, Color(0.42, 0.46, 0.4), 0.025)
	_stains(10, 0.4, Color(0.16, 0.15, 0.12), true)
	_grime(14, 14)
	_tags(7, 14, split + 30)


## Stairwell: bottle green gloss to 1.3 m, a black line, yellowed cream above.
func _stairs() -> void:
	var split := int(1.3 * PPM)
	_fill(0, split, Color(0.15, 0.23, 0.19), 0.02)
	_line(split, split + 3, Color(0.05, 0.05, 0.05))
	_fill(split + 3, TILE.y, Color(0.5, 0.47, 0.38), 0.03)
	_stains(12, 0.45, Color(0.2, 0.18, 0.12), false)
	_grime(18, 10)
	_tags(6, 20, split + 40)
	# Scuffs of the handrail and shoulders along the walls.
	for x in TILE.x:
		if _rng.randf() < 0.5:
			_put(x, split + 10 + _rng.randi_range(0, 4), _pick(x, split + 10).darkened(0.3))


## Storey corridor: dark dado to 1.1 m, striped green-grey wallpaper above.
func _corridor() -> void:
	_wallpaper(Color(0.36, 0.4, 0.36), Color(0.3, 0.33, 0.33), 16, 3)
	var split := int(1.1 * PPM)
	_fill(0, split, Color(0.17, 0.19, 0.17), 0.02)
	_line(split, split + 2, Color(0.05, 0.05, 0.05))
	_grime(10, 10)
	_tags(2, 10, split)


## Living room: beige floral wallpaper, torn and yellowed.
func _living() -> void:
	_wallpaper(Color(0.46, 0.42, 0.32), Color(0.38, 0.3, 0.28), 16, 6)


## Bedroom: faded blue wallpaper with a child's height marks by the door.
func _bedroom() -> void:
	_wallpaper(Color(0.34, 0.38, 0.42), Color(0.44, 0.44, 0.4), 12, 4)
	var x := 200
	for i in 6:
		var y := int((0.8 + i * 0.12) * PPM)
		for dx in 7:
			_put(x + dx, y, Color(0.08, 0.08, 0.1))


## Kitchen and bathroom: white faience to 1.5 m, painted wallpaper above.
func _kitchen() -> void:
	_wallpaper(Color(0.4, 0.42, 0.36), Color(0.36, 0.38, 0.32), 16, 2)
	var split := int(1.5 * PPM)
	_tiles(0, split, 16, Color(0.47, 0.47, 0.44), Color(0.26, 0.26, 0.24), 0.02)
	_stains(8, 0.35, Color(0.22, 0.2, 0.12), true)
	_grime(6, 8)


## Cellars: whitewash over concrete, damp rising from the floor.
func _cellar() -> void:
	_fill(0, TILE.y, Color(0.44, 0.44, 0.41), 0.04)
	for y in 50:
		for x in TILE.x:
			var damp := (1.0 - y / 50.0) * _rng.randf_range(0.5, 1.0)
			_put(x, y, _pick(x, y).lerp(Color(0.16, 0.18, 0.14), damp * 0.7))
	_stains(14, 0.5, Color(0.18, 0.18, 0.15), false)
	_grime(24, 8)
	_tags(4, 20, 120)


## Ceiling: stained plaster, water marks.
func _ceiling() -> void:
	_fill(0, TILE.y, Color(0.37, 0.37, 0.34), 0.03)
	_stains(9, 0.55, Color(0.22, 0.19, 0.12), false)
	_stains(4, 0.4, Color(0.12, 0.12, 0.11), false)


## Granito floor of the hall and landings.
func _terrazzo() -> void:
	for y in TILE.y:
		for x in TILE.x:
			var r := _rng.randf()
			var base := Color(0.34, 0.3, 0.25)
			if r < 0.08:
				base = base.darkened(0.45)
			elif r < 0.14:
				base = base.lightened(0.25)
			_put(x, y, _noise(base, 0.03))
	_stains(10, 0.4, Color(0.14, 0.12, 0.1), false)


## Brown lino in checks, worn along the middle.
func _lino() -> void:
	for y in TILE.y:
		for x in TILE.x:
			var dark := ((x / 32) + (y / 32)) % 2 == 0
			_put(x, y, _noise(Color(0.3, 0.25, 0.2) if dark else Color(0.22, 0.18, 0.15), 0.03))
	_stains(12, 0.35, Color(0.12, 0.1, 0.08), false)


## Parquet strips, dirty and scratched.
func _parquet() -> void:
	for y in TILE.y:
		for x in TILE.x:
			var strip := y / 12
			var tone := 0.03 * sin(strip * 7.3) + 0.02 * sin(float(x + strip * 37) * 0.3)
			var c := Color(0.26 + tone, 0.18 + tone, 0.12 + tone * 0.5)
			if y % 12 == 0 or (x + strip * 53) % 64 == 0:
				c = c.darkened(0.4)
			_put(x, y, _noise(c, 0.015))
	_stains(10, 0.35, Color(0.1, 0.08, 0.06), false)


## Bare concrete of the cellars, oil and water stains.
func _concrete() -> void:
	_fill(0, TILE.y, Color(0.3, 0.3, 0.29), 0.05)
	_stains(12, 0.5, Color(0.12, 0.12, 0.12), false)


# --- Hospital (S-014) ----------------------------------------------------------


## Scuffs in a band of heights: the gurneys and the trolleys rubbing the wall.
func _scuffs(count: int, y0: int, y1: int) -> void:
	for i in count:
		var x := _rng.randi_range(0, TILE.x - 1)
		var y := _rng.randi_range(y0, y1)
		for dx in _rng.randi_range(8, 30):
			_put_wrap(x + dx, y, _pick(x + dx, y).darkened(0.35))


## Paint flaking off in patches, the plaster or older paint showing.
func _flakes(count: int, under: Color) -> void:
	for i in count:
		var cx := _rng.randi_range(0, TILE.x - 1)
		var cy := _rng.randi_range(20, TILE.y - 1)
		var r := _rng.randf_range(3, 10)
		for y in range(int(cy - r), int(cy + r)):
			for x in range(int(cx - r * 1.5), int(cx + r * 1.5)):
				var d := Vector2((x - cx) / 1.5, y - cy).length()
				if d < r - _rng.randf_range(0, 2):
					_put_wrap(x, y, _noise(under, 0.02))
				elif d < r + 1:
					_put_wrap(x, y, _pick(x, y).darkened(0.3))


## Hospital corridor: sea-green gloss to 1.4 m under a grey bumper rail,
## dirty cream above, scuffed by the gurneys.
func _ward_corridor() -> void:
	var split := int(1.4 * PPM)
	_fill(0, split, Color(0.3, 0.42, 0.37), 0.02)
	_line(split, split + 2, Color(0.1, 0.1, 0.1))
	_fill(split + 2, TILE.y, Color(0.5, 0.5, 0.43), 0.025)
	_line(int(0.9 * PPM), int(0.9 * PPM) + 6, Color(0.3, 0.31, 0.3))  # The bumper rail.
	_line(int(0.9 * PPM) + 6, int(0.9 * PPM) + 7, Color(0.12, 0.12, 0.12))
	_scuffs(40, 6, int(0.9 * PPM))
	_flakes(5, Color(0.42, 0.42, 0.38))
	_stains(10, 0.4, Color(0.2, 0.18, 0.12), false)
	_grime(16, 14)


## Morgue, theatres, care rooms: dirty white faience to the ceiling, tiles
## missing, rust-brown runs.
func _faience() -> void:
	_tiles(0, TILE.y, 16, Color(0.6, 0.61, 0.57), Color(0.33, 0.34, 0.31), 0.025)
	_stains(8, 0.45, Color(0.3, 0.2, 0.12), true)
	_stains(5, 0.3, Color(0.22, 0.24, 0.2), false)
	for i in 6:  # Runs down from a crack.
		var x := _rng.randi_range(0, TILE.x - 1)
		var top := _rng.randi_range(60, TILE.y - 1)
		for dy in _rng.randi_range(20, 60):
			_put(x, top - dy, _pick(x, top - dy).lerp(Color(0.3, 0.19, 0.11), 0.5))
	_grime(8, 10)


## Wards and offices: sea-green paint to the ceiling, peeling, damp.
func _ward() -> void:
	_fill(0, TILE.y, Color(0.4, 0.48, 0.43), 0.025)
	_line(0, 5, Color(0.2, 0.22, 0.2))  # The skirting.
	_flakes(9, Color(0.5, 0.49, 0.43))
	_stains(9, 0.4, Color(0.22, 0.2, 0.13), false)
	_grime(20, 16)


## Sheet linoleum, pale grey-green, welded seams, wheel tracks, stains.
func _ward_lino() -> void:
	for y in TILE.y:
		for x in TILE.x:
			var c := Color(0.36, 0.4, 0.37)
			if x % 128 == 0:
				c = Color(0.2, 0.22, 0.2)  # A seam.
			elif _rng.randf() < 0.05:
				c = c.lightened(0.08)
			_put(x, y, _noise(c, 0.02))
	for track: int in [70, 100, 156, 186]:  # The wheels' tracks, along the corridor.
		for y in TILE.y:
			for dx in 3:
				_put(track + dx, y, _pick(track + dx, y).darkened(0.18))
	_stains(14, 0.4, Color(0.18, 0.16, 0.12), false)
