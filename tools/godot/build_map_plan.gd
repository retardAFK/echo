extends Node
## Makes the plan of the cité des Tilleuls that the hunted can open (spec
## S-017, T-251), from the figures build_tilleuls.gd builds the map with:
##   godot --headless tools/godot/build_map_plan.tscn
## Run it again after a change of the map's layout, then commit the plan.
## It shows the place only (S-017, Q2): the transformer and the exit tunnel
## are drawn without a name, and nothing says where the fuses are.

const Tilleuls := preload("res://tools/godot/tilleuls_layout.gd")
const PLAN_PATH := "res://game/maps/tilleuls/tilleuls_plan.tres"

## Out-of-reach bands around the cité, as on the paper plan (plan meters).
const RAILWAY_WEST := Rect2(0, 0, 150, 10)
const RAILWAY_EAST := Rect2(160, 0, 60, 10)
const TUNNEL := Rect2(150, 0, 10, 12)
const MOTORWAY := Rect2(210.5, 10, 9.5, 210)
const BOULEVARD := Rect2(0, 212.2, 210.5, 7.8)
const WASTELAND := Rect2(0, 10, 6, 202.2)
const PLAYGROUND := Rect2(50, 70, 22, 22)
const STADIUM := Rect2(148, 180, 30, 20)
const TRANSFORMER := Rect2(96, 150, 9, 7)

const BLOCK_KEYS := {
	"BarreA": "MAP_BLOCK_A",
	"BarreB": "MAP_BLOCK_B",
	"BarreD": "MAP_BLOCK_D",
	"BarreE": "MAP_BLOCK_E",
	"BarreF": "MAP_BLOCK_F",
	"BarreG": "MAP_BLOCK_G",
}


func _ready() -> void:
	var error := ResourceSaver.save(make_plan(), PLAN_PATH)
	print("Saved %s, error %d" % [PLAN_PATH, error])
	get_tree().quit(error)


static func make_plan() -> MapPlan:
	var plan := MapPlan.new()
	plan.title_key = "MAP_TITLE_TILLEULS"
	plan.size = Vector2(Tilleuls.MAP_SIZE, Tilleuls.MAP_SIZE)
	plan.origin = plan.size / 2.0
	plan.add(RAILWAY_WEST, MapPlan.Kind.EDGE, "MAP_RAILWAY")
	plan.add(RAILWAY_EAST, MapPlan.Kind.EDGE)
	plan.add(MOTORWAY, MapPlan.Kind.EDGE, "MAP_MOTORWAY")
	plan.add(BOULEVARD, MapPlan.Kind.EDGE, "MAP_BOULEVARD")
	plan.add(WASTELAND, MapPlan.Kind.EDGE, "MAP_WASTELAND")
	plan.add(TUNNEL, MapPlan.Kind.PATH)
	var half := Tilleuls.PATH_WIDTH / 2.0
	for line: Array in Tilleuls.PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half
			plan.add(Rect2(lo, hi - lo), MapPlan.Kind.PATH)
	plan.add(Tilleuls.CAR_PARK_RAMP, MapPlan.Kind.PATH)
	plan.add(PLAYGROUND, MapPlan.Kind.PLACE, "MAP_PLAYGROUND")
	plan.add(STADIUM, MapPlan.Kind.PLACE, "MAP_STADIUM")
	plan.add(TRANSFORMER, MapPlan.Kind.STRUCTURE)
	for block: String in Tilleuls.FACADES:
		plan.add(Tilleuls.FACADES[block][0], MapPlan.Kind.BLOCK, BLOCK_KEYS[block])
	plan.add(Tilleuls.TOWER, MapPlan.Kind.BUILDING, "BUILDING_TOWER")
	plan.add(Tilleuls.SOCIAL_CENTRE, MapPlan.Kind.BUILDING, "BUILDING_SOCIAL_CENTRE")
	plan.add(Tilleuls.GALLERY, MapPlan.Kind.BUILDING, "BUILDING_GALLERY")
	plan.add(Tilleuls.CAR_PARK, MapPlan.Kind.BUILDING, "BUILDING_CAR_PARK")
	plan.add(Tilleuls.GARAGES, MapPlan.Kind.BUILDING, "BUILDING_GARAGES")
	plan.add(Tilleuls.Hospital.RECT, MapPlan.Kind.BUILDING, "BUILDING_HOSPITAL")
	return plan
