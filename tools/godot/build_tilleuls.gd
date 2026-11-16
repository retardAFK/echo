extends Node
## Generates the cité des Tilleuls (spec S-006) from its validated paper plan
## (specs/S-006-cite-des-tilleuls/plan-map.svg): ground, borders, blocks of flats,
## visitable buildings, landmarks, gameplay points, then bakes the navigation mesh.
## Run after any change, then commit the scene and the navigation mesh:
##   godot --headless tools/godot/build_tilleuls.tscn
## (a scene rather than -s, so the autoloads the game scripts use are loaded).
## The map is only edited here: a hand edit of the scene is lost on the next run.
## Coordinates are plan coordinates (see map_kit.gd): x east, y south, meters.

const MapKit := preload("res://tools/godot/map_kit.gd")
const InteriorLining := preload("res://tools/godot/interior_lining.gd")
const Hospital := preload("res://tools/godot/hospital.gd")

## Binary and compressed (T-194): 1 MB instead of 11 MB in the web build.
const SCENE_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const NAVMESH_PATH := "res://game/maps/tilleuls/tilleuls_navmesh.res"

const MAP_SIZE := 220.0
## Ground tiles: a light only touches the few tiles around it.
const GROUND_TILE := 40.0
const GROUND_THICKNESS := 0.2
## Inside the fences, in plan meters: west fence to noise wall, far end of the
## exit tunnel to site fence. The north edge stays a whole number of navigation
## cells (0.125 m) from where it was before S-007, so the voxel grid, and the
## mesh everywhere else, do not move.
const FENCED := Rect2(6, 0.3, 204.5, 211.9)
const NAV_BOTTOM := -5.24
const PATH_WIDTH := 5.0
const PATH_HEIGHT := 0.04
## One storey of a block of flats, in meters.
const STOREY := 3.0

const MAT_DIRT := preload("res://game/fx/materials/ground_dirt.tres")
const MAT_ASPHALT := preload("res://game/fx/materials/asphalt_floor.tres")
const MAT_CONCRETE := preload("res://game/fx/materials/concrete_wall.tres")
const MAT_OBSTACLE := preload("res://game/fx/materials/concrete_obstacle.tres")

const PLAYER := preload("res://game/entities/player/player.tscn")
const MONSTER := preload("res://game/entities/monster/monster.tscn")
## How far a fuse box looks for a wall around its slot, in meters.
const FUSE_BOX_WALL_SEARCH := 3.5
const BUILDING := preload("res://game/entities/building/building.tscn")
const FUSE_BOX := preload("res://game/entities/fuse_box/fuse_box.tscn")
const TRANSFORMER_NODE := preload("res://game/entities/transformer/transformer.tscn")
const EXIT_GATE_SCRIPT := preload("res://game/entities/exit/exit_gate.gd")
const EXIT_ZONE_SCRIPT := preload("res://game/entities/exit/exit_zone.gd")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
## The grille of the exit tunnel, and the far end of the tunnel (plan, S-007).
const EXIT_GATE := Rect2(150, 2.8, 10, 0.4)
const EXIT_GATE_HEIGHT := 3.6
const EXIT_ZONE := Rect2(150.5, 0, 9, 2.6)
const OVERLAY := preload("res://game/ui/debug_overlay.tscn")
const NOISE_DEBUG := preload("res://game/ui/noise_debug.tscn")
const GAUGE := preload("res://game/ui/noise_gauge.tscn")
const CAUGHT := preload("res://game/ui/caught_screen.tscn")
const INTERACT_PROMPT := preload("res://game/ui/interact_prompt.tscn")
const CAR_ALARM := preload("res://game/entities/car_alarm/car_alarm.tscn")
## The car alarm under the hospital's canopy is the abandoned ambulance (S-014).
const AMBULANCE_ALARM := preload("res://game/entities/car_alarm/ambulance_alarm.tscn")
const AMBULANCE_CAR := 4
const RETRO_POST := preload("res://game/fx/retro_post.tscn")
const LAMPPOST := preload("res://game/entities/props/lamppost.tscn")
const BENCH_DIRTY := preload("res://game/entities/props/bench_dirty.tscn")
const BENCH_BROKEN := preload("res://game/entities/props/bench_broken.tscn")
const TREE_BARE := preload("res://game/entities/props/tree_bare.tscn")
const FACADE_DRESSING := preload("res://game/maps/facade_dressing.gd")
## Models of the gallery and the social centre (T-046, tools/blender/gallery.py),
## front toward +Z, origin at the bottom corner on the left seen from outside.
const SHOP_HALF := preload("res://assets/models/gallery_shop_half.glb")
const LAUNDRETTE := preload("res://assets/models/gallery_laundrette.glb")
const SHOP_PHARMACIE := preload("res://assets/models/shop_pharmacie.glb")
const SHOP_TABAC := preload("res://assets/models/shop_tabac.glb")
const SHOP_BOULANGERIE := preload("res://assets/models/shop_boulangerie.glb")
const WASHERS := preload("res://assets/models/gallery_washers.glb")
## Furniture of the interiors (S-016, Q7, T-240, tools/blender/interiors.py):
## centred on its footprint, its front toward +Z.
const FURNITURE_SCRIPT := preload("res://game/maps/furniture.gd")
const FURNITURE_MODELS := {
	"bed": preload("res://assets/models/bed.glb"),
	"sofa": preload("res://assets/models/sofa.glb"),
	"kitchen_table": preload("res://assets/models/kitchen_table.glb"),
	"fridge": preload("res://assets/models/fridge.glb"),
	"boxes": preload("res://assets/models/boxes.glb"),
	"chairs_stacked": preload("res://assets/models/chairs_stacked.glb"),
	"stage_curtain": preload("res://assets/models/stage_curtain.glb"),
	"oven": preload("res://assets/models/oven.glb"),
	"counter": preload("res://assets/models/counter.glb"),
	"shelves": preload("res://assets/models/shelves.glb"),
	"lift_doors": preload("res://assets/models/lift_doors.glb"),
	# The hospital (S-014, T-189, tools/blender/hospital_kit.py).
	"hospital_bed": preload("res://assets/models/hospital/hospital_bed.glb"),
	"morgue_drawers": preload("res://assets/models/hospital/morgue_drawers.glb"),
	"curtain": preload("res://assets/models/hospital/curtain.glb"),
	"iv_pole": preload("res://assets/models/hospital/iv_pole.glb"),
}
## What only shows, and stops nobody: the curtains, the lift doors on its
## shaft, the drip stands.
const FURNITURE_GHOSTS := ["stage_curtain", "lift_doors", "curtain", "iv_pole"]
const CENTRE_WINDOW := preload("res://assets/models/centre_window.glb")
const CENTRE_ENTRANCE := preload("res://assets/models/centre_entrance.glb")
const FOLDING_TABLE := preload("res://assets/models/folding_table.glb")
const CENTRE_WINDOW_WIDTH := 2.0
## Models of the car park and the garages (T-047, tools/blender/car_park.py).
const CAR_WRECK := preload("res://assets/models/car_wreck.glb")
const CAR_PARK_SIGN := preload("res://assets/models/car_park_sign.glb")
const CAR_PARK_PILLAR := preload("res://assets/models/car_park_pillar.glb")
const NEON_FIXTURE := preload("res://assets/models/neon_fixture.glb")
const GARAGE_CLOSED := preload("res://assets/models/garage_closed.glb")
const GARAGE_OPEN := preload("res://assets/models/garage_open.glb")
## Outdoor models (T-048, tools/blender/outdoor.py).
const TRANSFORMER := preload("res://assets/models/transformer.glb")
const SWING := preload("res://assets/models/swing.glb")
## Ambient sounds (T-050), made by tools/audio/ambience.py.
const WIND_SOUND := preload("res://assets/audio/ambience/wind.wav")
const MOTORWAY_SOUND := preload("res://assets/audio/ambience/motorway.wav")
const TRAIN_SOUND := preload("res://assets/audio/ambience/train.wav")
const SWING_SOUND := preload("res://assets/audio/ambience/swing_creak.wav")
const AMBIENT_TRAIN := preload("res://game/audio/ambient_train.gd")
## Where the motorway is heard from, along the east fence (plan y).
const MOTORWAY_SOURCES := [40.0, 110.0, 180.0]
const CLIMBING_FRAME := preload("res://assets/models/climbing_frame.glb")
const STADIUM_BOARD := preload("res://assets/models/stadium_board.glb")
const STADIUM_GOAL := preload("res://assets/models/stadium_goal.glb")
const STADIUM_BOARD_WIDTH := 2.0
const CAR_PARK_WRECKS := [Vector2(154, 98.5), Vector2(160, 113.5), Vector2(166, 101)]
## Facade modules of S-005 (3 x 3 m, front toward +Z), in FacadeDressing order.
const FACADE_MODELS := [
	preload("res://assets/models/facade_hlm_plain.glb"),
	preload("res://assets/models/facade_hlm_lit.glb"),
	preload("res://assets/models/facade_hlm_balcony.glb"),
	preload("res://assets/models/facade_hlm_walled.glb"),
	preload("res://assets/models/facade_hlm_door.glb"),
	preload("res://assets/models/facade_hlm_open.glb"),
]
## OPEN has a real hole: it dresses the visited storeys of the tower, in front
## of their window openings.
enum Module { PLAIN, LIT, BALCONY, WALLED, DOOR, OPEN }
const MODULE_WIDTH := 3.0
## Share of lit windows and of balcony columns on the upper storeys, and of
## walled-up windows on the ground floor. A door every DOOR_SPACING meters.
const LIT_SHARE := 0.15
const BALCONY_SHARE := 0.35
const WALLED_SHARE := 0.5
const DOOR_SPACING := 18.0
## The panels stand this far out of the greybox walls, so they never flicker.
const FACADE_OFFSET := 0.05
const MAP_SCRIPT := preload("res://game/maps/game_map.gd")
const NIGHT_SCRIPT := preload("res://game/fx/night_environment.gd")
const RETRO_WORLD_SCRIPT := preload("res://game/fx/retro_world.gd")

## Paths of the plan, as polylines of plan points.
const PATHS := [
	[Vector2(155, 12), Vector2(155, 50), Vector2(105, 50), Vector2(105, 185), Vector2(40, 185)],
	[Vector2(105, 120), Vector2(200, 120), Vector2(200, 200)],
	[Vector2(40, 50), Vector2(105, 50)],
	[Vector2(40, 50), Vector2(40, 185)],
]

## Blocks of flats seen from outside only (plan A to G): rectangle, storeys,
## and the porch through it, if any (x range under the block, 4 m high).
## B's porch carries the path to the exit; the porches of A and E keep a run
## across the map under 45 s (T-041).
const FACADES := {
	"BarreA": [Rect2(15, 22, 70, 12), 5, Vector2(47, 53)],
	"BarreB": [Rect2(125, 22, 70, 12), 5, Vector2(150, 160)],
	"BarreD": [Rect2(185, 55, 12, 55), 5, null],
	"BarreE": [Rect2(45, 192, 55, 12), 5, Vector2(70, 76)],
	"BarreF": [Rect2(125, 160, 12, 40), 4, null],
	"BarreG": [Rect2(150, 145, 45, 10), 4, null],
}
const PORCH_HEIGHT := 4.0

## Walls of the visitable buildings, in meters.
const WALL := 0.3
const SLAB := 0.3
## Above the monster (2.2 m) and its navigation height (2.25 m).
const DOOR_TOP := 2.4
const DOOR_WIDTH := 1.2
const WINDOW_SILL := 1.0
## Windows of the tower match the openings of the facade modules (T-045).
const WINDOW_TOP := 2.4
const WINDOW_WIDTH := 1.2
const WINDOW_STEP := 3.0
const WINDOW_INSET := 0.9

## Tour des Tilleuls (Q3, Q4): footprint, visitable storeys, storeys seen from outside.
const TOWER := Rect2(92, 88, 24, 24)
const TOWER_VISITED_STOREYS := 5
const TOWER_STOREYS := 13
## Stairwell: two flights side by side, landing to the south on the corridor.
const STAIR_X := 101.0
const STAIR_FLIGHT_WIDTH := 2.0
const STAIR_DIVIDER := 0.4
const STAIR_LANDING_Y := 98.5  ## South end of the flights, on the corridor.
const STAIR_FLIGHT_LENGTH := 4.0
const STAIR_MID_LANDING := 1.5
## Corridor across each storey, between the north and south flats.
const CORRIDOR := Vector2(98.5, 101.5)
## Double doors of the hall, north and south (S-016).
const TOWER_NORTH_DOORS := Vector2(106, 110)
const TOWER_SOUTH_DOORS := Vector2(103, 107)
## Door of each corridor onto the fire escape, in the east wall (Q4).
const FIRE_ESCAPE_DOOR := Vector2(99.4, 100.6)
## Fire door from the hall to the cellar stairs, in the wall at x = 99.
const CELLAR_DOOR := Vector2(93, 94.2)
## Hole in the partition between the south flats, to crawl through.
const TOWER_CRAWL_HOLE := Vector2(104.6, 105.8)
const TOWER_CRAWL_HEIGHT := 1.0
## The stuck lift, west of the stairs.
const LIFT_SHAFT := Rect2(99.15, 88.3, 1.7, 2.7)
## Cellars (Q5): stairs down from the tower, a corridor to the car park, the
## cages along it in alcoves to the north.
const CELLAR_STAIRS := Rect2(92.6, 96.0, 6.0, 2.4)
## Flat top of the cellar stairs, open to the north, in meters.
const CELLAR_LANDING := 1.4
const CELLAR_CORRIDOR := Rect2(92.6, 96.0, 47.4, 2.4)
const CELLAR_FIRE_DOORS := [116.5, 139.0]
const CELLAR_CAGES := Vector2(118, 136)
const CELLAR_CAGE_DEPTH := 1.8
## The prison (S-018, Q1): the three westmost cellar cages, by index, each
## with a gate in the east end of its grille.
const PRISON_CAGES := [0, 1, 2]
const PRISON_GATE_WIDTH := 1.4
const CAGE := preload("res://game/entities/prison/cage.tscn")
const PRISON_SCRIPT := preload("res://game/entities/prison/prison.gd")
const PRISON_SETTINGS := preload("res://game/data/prison_settings.tres")
## The network of the cité (S-018, Q9 to Q11), Vector3(x, h, y) on the plan.
## Terminals: where the front of the desk stands, the way the screen and the
## one at the keyboard face (degrees, 0 = south, 90 = east, 180 = north,
## -90 = west), the kind, the name.
const TERMINALS := [
	[Vector3(115.3, 0.0, 106.0), -90.0, Terminal.Kind.NORMAL, "NET_TERM_TOWER"],
	[Vector3(177.3, 0.0, 62.0), -90.0, Terminal.Kind.NORMAL, "NET_TERM_CENTRE_OFFICE"],
	[Vector3(150.0, 0.0, 83.3), 180.0, Terminal.Kind.NORMAL, "NET_TERM_CENTRE_HALL"],
	[Vector3(80.0, 0.0, 146.4), 180.0, Terminal.Kind.NORMAL, "NET_TERM_BAKERY"],
	[Vector3(176.5, -3.0, 102.4), 0.0, Terminal.Kind.NORMAL, "NET_TERM_CAR_PARK"],
	[Vector3(51.5, 0.0, 146.4), 180.0, Terminal.Kind.GUARD, "NET_TERM_GUARD"],
	[Vector3(106.5, 0.0, 153.5), 90.0, Terminal.Kind.CODE, "NET_TERM_KEYPAD"],
]
## The relay switches (S-018, Q13), snapped to the nearest wall like the fuse
## boxes: Vector3(x, h, y) on the plan, the building. Pairs at most
## relay_max_distance apart: tower and gallery, tower and centre, centre and
## car park.
const RELAYS := [
	[Vector3(95.0, -3.0, 96.1), "tower"],
	[Vector3(156.0, 0.0, 81.0), "centre"],
	[Vector3(60.0, 0.0, 148.0), "gallery"],
	[Vector3(177.6, -3.0, 101.85), "car_park"],
]
const RELAY_SWITCH := preload("res://game/entities/objectives/relay_switch.tscn")
const CODE_SPOT := preload("res://game/entities/objectives/code_spot.tscn")
## Cameras: where it hangs, what it looks at, its name.
const CAMERAS := [
	[Vector3(137.5, -0.6, 96.3), Vector3(121.0, -2.5, 95.5), "NET_CAM_CELLARS"],
	[Vector3(179.5, -0.6, 116.5), Vector3(155.0, -3.0, 103.0), "NET_CAM_CAR_PARK"],
	[Vector3(127.0, 2.6, 99.6), Vector3(138.0, -2.0, 102.0), "NET_CAM_RAMP"],
	[Vector3(115.5, 2.6, 111.5), Vector3(104.0, 1.0, 96.0), "NET_CAM_TOWER_HALL"],
	[Vector3(159.5, 3.4, 60.5), Vector3(145.0, 0.5, 78.0), "NET_CAM_CENTRE_HALL"],
	[Vector3(86.5, 3.0, 135.5), Vector3(50.0, 0.5, 137.0), "NET_CAM_ARCADE"],
	[Vector3(108.0, 3.0, 160.0), Vector3(100.5, 1.0, 153.5), "NET_CAM_TRANSFORMER"],
	[Vector3(110.0, 3.5, 112.4), Vector3(105.0, 0.0, 128.0), "NET_CAM_TOWER_SOUTH"],
]
## Loudspeakers: where they hang, the yaw of their back to the wall (degrees,
## their front looks along -Z), the name.
const SPEAKERS := [
	[Vector3(141.6, 2.6, 70.0), -90.0, "NET_SPEAKER_STAGE"],
	[Vector3(115.8, 2.2, 101.0), 90.0, "NET_SPEAKER_TOWER"],
	[Vector3(66.0, 2.4, 139.1), 0.0, "NET_SPEAKER_ARCADE"],
]
## Metal shutters: the bottom middle of the opening, its yaw (90: across a
## north-south way), width, height, the name.
const SHUTTERS := [
	[Vector3(140.0, -3.0, 102.0), 90.0, 4.0, 2.8, "NET_SHUTTER_RAMP"],
	[Vector3(85.9, 0.0, 148.0), 90.0, 1.7, 3.5, "NET_SHUTTER_GALLERY"],
]
const LOUDSPEAKER := preload("res://game/entities/network/loudspeaker.tscn")
const REMOTE_SHUTTER := preload("res://game/entities/network/remote_shutter.tscn")
const TERMINAL := preload("res://game/entities/network/terminal.tscn")
const SECURITY_CAMERA := preload("res://game/entities/network/security_camera.tscn")
const NETWORK_SCRIPT := preload("res://game/entities/network/city_network.gd")

const SOCIAL_CENTRE := Rect2(140, 60, 38, 24)
const SOCIAL_CENTRE_HEIGHT := 4.0
## Doorways of the social centre (S-016): north and west entrances, the
## emergency exit at the end of the corridor, the kitchen's back door.
const CENTRE_NORTH_DOORS := Vector2(160.4, 162.6)
const CENTRE_WEST_DOORS := Vector2(70.0, 73.0)
const CENTRE_EMERGENCY_EXIT := Vector2(160.4, 162.6)
const CENTRE_KITCHEN_DOOR := Vector2(157.0, 158.2)
const CENTRE_KITCHEN := Rect2(152, 78, 8, 6)
## The stage: the curtain runs along its west edge, the wings behind it.
const CENTRE_STAGE := Rect2(141.4, 64, 2.6, 12)
const GALLERY := Rect2(45, 135, 42, 14)
const GALLERY_HEIGHT := 3.5
const GALLERY_ARCADE_DEPTH := 4.0
const GALLERY_SHOPS := 5
const GALLERY_BACK_CORRIDOR := 2.0
## The half-raised shutter: only a crouching hunted gets under it.
const SHUTTER_TOP := 1.1
## Shop fronts of the gallery, west to east (S-016): pharmacy, laundrette,
## tobacconist (shutter to roll up), grocer (shutter half down), baker.
const GALLERY_FRONTS := [
	Vector2(45.8, 47.0), Vector2(55.4, 57.8), Vector2(63.8, 67.8), Vector2(72.2, 75.2), Vector2(80.6, 81.8),
]
const GALLERY_HALF_SHUTTER := 3
## Steep metal stairs up to the roof: behind the back wall (x from, x to)
## and along the east wall (y from, y to), their width.
const GALLERY_BACK_STAIRS := Vector2(60.0, 66.5)
const GALLERY_EAST_STAIRS := Vector2(139.0, 145.0)
const GALLERY_ROOF_STAIR_WIDTH := 1.2

const CAR_PARK := Rect2(140, 95, 40, 22)
const CAR_PARK_DEPTH := 3.0
const CAR_PARK_RAMP := Rect2(128, 100, 12, 4)
const CAR_PARK_STAIRS := Rect2(172, 112, 6, 2.5)
## The new north stairs (S-016, Q4): up to the west, a fire door at their foot.
const CAR_PARK_NORTH_STAIRS := Rect2(170, 95.4, 6, 2.5)
## The technical room on the east wall, its door to the west.
const CAR_PARK_TECHNICAL := Rect2(174, 102, 6, 6)
const CAR_PARK_PILLAR_STEP := 8.0
const PARAPET := 1.0

const GARAGES := Rect2(9, 150, 8, 35)
const GARAGE_COUNT := 6
const GARAGE_HEIGHT := 2.5
const GARAGES_OPEN := [1, 4]

## Where the hunted may start, far from the monster (Q2).
const PLAYER_SPAWNS := [
	Vector2(45, 44), Vector2(95, 44), Vector2(32, 150), Vector2(72, 112),
	Vector2(127, 96), Vector2(170, 44),  # Clear of the tower's fire escape (S-016).
]
const MONSTER_SPAWN := Vector2(190, 190)

## The lights fade out from this distance to the camera, over LIGHT_FADE_LENGTH
## (T-049): farther, only their baked light shows. Same as lamppost.tscn.
const LIGHT_FADE_BEGIN := 20.0
const LIGHT_FADE_LENGTH := 5.0
## Lampposts: plan position and the direction the arm points to.
const LAMPPOSTS := [
	[Vector2(158, 20), Vector2.LEFT], [Vector2(158, 46), Vector2.LEFT],
	[Vector2(130, 47), Vector2.DOWN], [Vector2(80, 47), Vector2.DOWN],
	[Vector2(50, 47), Vector2.DOWN], [Vector2(37, 80), Vector2.RIGHT],
	[Vector2(37, 112), Vector2.RIGHT], [Vector2(37, 145), Vector2.RIGHT],
	[Vector2(37, 178), Vector2.RIGHT], [Vector2(72, 188), Vector2.UP],
	[Vector2(102, 160), Vector2.RIGHT], [Vector2(108, 135), Vector2.LEFT],
	[Vector2(108, 75), Vector2.LEFT], [Vector2(135, 117), Vector2.DOWN],
	[Vector2(168, 123), Vector2.UP], [Vector2(197, 150), Vector2.RIGHT],
	[Vector2(203, 180), Vector2.LEFT], [Vector2(61, 84.5), Vector2.UP],
	[Vector2(163, 178), Vector2.DOWN],
]

## The 6 cars with an alarm (Q7), parked along the streets: plan position and
## the direction of their length.
const CAR_ALARMS := [
	[Vector2(36, 45), Vector2.RIGHT], [Vector2(120, 45), Vector2.RIGHT],
	[Vector2(205, 140), Vector2.UP], [Vector2(85, 170), Vector2.RIGHT],
	[Vector2(35, 106), Vector2.UP], [Vector2(186, 206), Vector2.RIGHT],
]

## Benches and trees: plan position and the direction they face.
const BENCHES := [
	[Vector2(52, 90), Vector2.UP, false], [Vector2(70, 90), Vector2.UP, true],
	[Vector2(110, 125), Vector2.UP, false], [Vector2(150, 178), Vector2.UP, true],
	[Vector2(44, 160), Vector2.LEFT, false],
]
const TREES := [
	Vector2(48, 68), Vector2(74, 72), Vector2(49, 95), Vector2(36, 53), Vector2(82, 160),
	Vector2(120, 140), Vector2(176, 128), Vector2(140, 40), Vector2(112, 60), Vector2(64, 120),
	Vector2(20, 186), Vector2(185, 170),
]

## Ruses (S-008, T-067), as plan points (x, height, y). Each spot is laid
## against the nearest wall, its door toward the room; each pickup on what is
## below its point (ground, low wall, workbench).
const CLOSET := preload("res://game/entities/hiding_spot/closet.tscn")
const LOW_SPOT := preload("res://game/entities/hiding_spot/low_spot.tscn")
const MAKESHIFT_SPOT := preload("res://game/entities/hiding_spot/makeshift_spot.tscn")
const METAL_SPOT := preload("res://game/entities/hiding_spot/metal_spot.tscn")
const DOOR := preload("res://game/entities/door/door.tscn")
const DUMPSTER := preload("res://game/entities/hiding_spot/dumpster.tscn")
const BOTTLE := preload("res://game/entities/pickup/bottle_pickup.tscn")
const DECOY := preload("res://game/entities/pickup/decoy_pickup.tscn")
## How far a hiding spot looks for its wall, in meters, and at which height
## above the floor (under the window sills).
const SPOT_WALL_SEARCH := 2.5
const SPOT_RAY_HEIGHT := 0.5
## 3 closets in each visitable building (Q5).
const CLOSETS := [
	Vector3(93, 0, 109), Vector3(93.5, 3, 90), Vector3(103, 9, 109.5),  # Tower: bin room, flats.
	Vector3(164.2, 0, 61.5), Vector3(148, 0, 61), Vector3(176.8, 0, 82.5),  # Social centre.
	Vector3(54.2, 0, 141), Vector3(81.5, 0, 146.5), Vector3(45.8, 0, 141),  # Gallery.
	Vector3(141, -3, 112), Vector3(179, -3, 106), Vector3(152, -3, 95.8),  # Car park.
]
## The other families (S-016, Q6): low (under a bed), makeshift (behind a
## curtain), metal (the stuck lift). A third value places the spot there,
## its front toward that plan direction, instead of against the nearest wall.
const FAMILY_SPOTS := [
	["Metal", Vector3(100, 0, 91.6)],  # Tower: the lift cabin.
	["Low", Vector3(113, 3, 90)], ["Low", Vector3(101, 6, 110.5)], ["Low", Vector3(113, 9, 104.5)],
	["Makeshift", Vector3(92.6, 3, 103)], ["Makeshift", Vector3(115.6, 6, 104)],
	["Makeshift", Vector3(110, 12, 88.6)], ["Low", Vector3(101, 12, 110.5)],
	["Makeshift", Vector3(92.6, 9, 103)],
	["Low", Vector3(143, 0, 73.5), Vector2.RIGHT],  # Social centre: under the stage,
	["Low", Vector3(143, 0, 67), Vector2.RIGHT],
	["Makeshift", Vector3(140.85, 0, 65)], ["Makeshift", Vector3(158.2, 0, 63)],  # the wings, the chairs,
	["Metal", Vector3(153.5, 0, 83)],  # the kitchen's cold cabinet.
	["Low", Vector3(48.5, 0, 144.5)], ["Metal", Vector3(54, 0, 145.5)],  # Gallery: pharmacy, dryer,
	["Makeshift", Vector3(64.5, 0, 146.4)], ["Metal", Vector3(85.5, 0, 145.3)],  # boxes, oven.
	["Metal", Vector3(154, -3, 101.05), Vector2.DOWN],  # Car park: a wreck's boot,
	["Low", Vector3(160, -3, 113.5), Vector2.LEFT],  # under a wreck,
	["Metal", Vector3(166, -3, 103.55), Vector2.DOWN],  # another boot,
	["Makeshift", Vector3(129.2, -3, 94.6)],  # boxes in the open cellar cage.
]
## Furniture of every visited storey of the tower (S-016, Q7): model, plan
## point, its front toward that plan direction. North-west, north-east,
## south-west and south-east flats.
const FLAT_FURNITURE := [
	["bed", Vector2(93.3, 95.5), Vector2.RIGHT], ["sofa", Vector2(98.0, 88.55), Vector2.DOWN],
	["boxes", Vector2(100.0, 95.5), Vector2.LEFT], ["lift_doors", Vector2(100.0, 91.0), Vector2.DOWN],
	["bed", Vector2(114.8, 95.5), Vector2.LEFT], ["kitchen_table", Vector2(108.3, 92.5), Vector2.DOWN],
	["fridge", Vector2(106.1, 88.45), Vector2.DOWN],
	["sofa", Vector2(95.5, 106.45), Vector2.UP], ["boxes", Vector2(102.6, 102.9), Vector2.LEFT],
	["bed", Vector2(100.6, 110.85), Vector2.UP],
	["sofa", Vector2(115.45, 104.6), Vector2.LEFT], ["kitchen_table", Vector2(109.6, 104.2), Vector2.DOWN],
	["bed", Vector2(106.0, 110.85), Vector2.UP], ["fridge", Vector2(115.58, 102.0), Vector2.LEFT],
]
## The other furniture: model, plan point (x, height, y), front toward that
## plan direction, and a scale along the model's width if it is stretched.
const FURNITURE := [
	# Social centre: the stage curtain (a gap for the west doors), the stacked
	# chairs, the kitchen's range, the offices.
	["stage_curtain", Vector3(141.45, 0.6, 65.3), Vector2.RIGHT],
	["stage_curtain", Vector3(141.45, 0.6, 67.9), Vector2.RIGHT],
	["stage_curtain", Vector3(141.45, 0.6, 74.7), Vector2.RIGHT],
	["chairs_stacked", Vector3(157.7, 0, 61.1), Vector2.DOWN],
	["chairs_stacked", Vector3(158.9, 0, 61.1), Vector2.DOWN],
	["oven", Vector3(159.45, 0, 82.9), Vector2.LEFT],
	["shelves", Vector3(168, 0, 67.6), Vector2.UP], ["boxes", Vector3(166, 0, 75.2), Vector2.UP],
	# Gallery: counters of the pharmacy, the grocer and the baker, the
	# tobacconist's shelves.
	["counter", Vector3(48.5, 0, 143.4), Vector2.UP, 5.0 / 2.1],
	["shelves", Vector3(62.9, 0, 143), Vector2.RIGHT], ["shelves", Vector3(62.9, 0, 145), Vector2.RIGHT],
	["shelves", Vector3(66.4, 0, 143), Vector2.LEFT], ["shelves", Vector3(66.4, 0, 145), Vector2.LEFT],
	["counter", Vector3(74, 0, 143.4), Vector2.UP, 6.0 / 2.1],
	["counter", Vector3(82, 0, 142.4), Vector2.UP, 5.0 / 2.1],
	# Car park: the technical room.
	["shelves", Vector3(177, -3, 107.6), Vector2.UP],
]
## A piece of furniture keeps this far, on the ground plan, from a hiding
## spot, a pickup, a fuse slot or a point of the AIs on its level.
const FURNITURE_CLEARANCE := 0.5
## Furniture taller than this leaves no room on top for the navigation mesh.
const FURNITURE_TALL := 1.5

## 6 dumpsters outside, against the blocks of flats (Q5).
const DUMPSTERS := [
	Vector3(30, 0, 35), Vector3(33.2, 0, 128), Vector3(180, 0, 35),
	Vector3(184, 0, 92), Vector3(185, 0, 144), Vector3(90, 0, 191),
]
## 20 bottles, all there every game (Q1): low walls, benches, halls, car park.
const BOTTLES := [
	Vector3(55, 0, 70.15), Vector3(68, 0, 91.85), Vector3(50.15, 0, 85),  # Playground kerb.
	Vector3(53.5, 0, 90.5), Vector3(111.5, 0, 125.8), Vector3(151.5, 0, 178.6),  # Benches.
	Vector3(44.2, 0, 161.6), Vector3(148, 0, 184),  # Bench, city stadium board.
	Vector3(113, 0, 99), Vector3(100.5, 0, 110.5), Vector3(97, 6, 100),  # Tower.
	Vector3(161.5, 0, 82), Vector3(50, 0, 137.5), Vector3(82, 0, 137.5),  # Halls, arcade.
	Vector3(60.5, 0, 141), Vector3(150, -3, 115.8), Vector3(165, -3, 96),  # Laundrette, car park.
	Vector3(178.5, -3, 110), Vector3(125, 0, 104.5), Vector3(95, 0, 158),  # Ramp, transformer.
]
## 10 places for an alarm clock, 4 drawn each game by GameLoop (Q3): the open
## garages, the car park, the offices of the social centre, the back corridor
## of the gallery.
const DECOYS := [
	Vector3(10.2, 0, 157.2), Vector3(10.2, 0, 174.7),
	Vector3(146, -3, 96.5), Vector3(168, -3, 116.2), Vector3(156.8, -3, 102.33),
	Vector3(176, -3, 101.3), Vector3(173, 0, 61), Vector3(165, 0, 83),
	Vector3(50, 0, 148), Vector3(79, 0, 148),
]

var kit := MapKit.new()
var _root: Node3D
var _materials := {}
## Doors to place once the structures are built: plan position (x, h, y),
## yaw in degrees, width, kind (S-016).
var _doors: Array = []
var _metal_floors: Array[MetalFloor] = []
## Cages of the prison to place once the structures are built: the plan
## point (x, height, y) of the middle of each one's gate (S-018).
var _cages: Array[Vector3] = []


func _ready() -> void:
	kit.origin = Vector2(MAP_SIZE, MAP_SIZE) / 2.0
	_root = Node3D.new()
	_root.name = "Tilleuls"
	_build_ground()
	_build_borders()
	_build_facades()
	_build_landmarks()
	_build_tower()
	_build_social_centre()
	_build_gallery()
	_build_car_park()
	_build_cellars()
	Hospital.new(self).build()  # Spec S-014, in place of block C.
	_build_garages()
	_build_furniture()
	var lining := InteriorLining.new(self)
	lining.add_zones(kit)
	kit.build(_root)
	_add_doors()
	_add_buildings()
	Hospital.new(self).add_gameplay()  # Monitors and ventilation (S-014, T-186).
	_add_props()
	_add_navigation()
	_add_facade_dressing()
	_add_gallery_dressing()
	_add_social_centre_dressing()
	_add_car_park_dressing()
	_add_outdoor_dressing()
	_add_furniture()
	lining.dress(_root)
	_add_ambience()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bake_light()
	_place_fuse_boxes()
	_place_objectives()
	_place_ruses()
	var region: NavigationRegion3D = _root.get_node("NavigationRegion3D")
	var started := Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	var error := ResourceSaver.save(mesh, NAVMESH_PATH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(NAVMESH_PATH)
	print(
		"Baked %d polygons in %d ms, save error %d"
		% [mesh.get_polygon_count(), Time.get_ticks_msec() - started, error]
	)
	_root.get_parent().remove_child(_root)
	_add_gameplay()
	var packed := PackedScene.new()
	error = packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE_PATH, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s, error %d" % [SCENE_PATH, error])
	_root.free()
	get_tree().quit(error)


# --- Ground and borders -----------------------------------------------------


func _build_ground() -> void:
	var holes: Array[Rect2] = [CAR_PARK_RAMP, CAR_PARK_STAIRS, CAR_PARK_NORTH_STAIRS, CELLAR_STAIRS]
	holes.append_array(Hospital.ground_holes())
	kit.slab_tiles(
		"Tile", Rect2(0, 0, MAP_SIZE, MAP_SIZE), holes, -GROUND_THICKNESS, 0.0, MAT_DIRT,
		GROUND_TILE
	)
	var roads := kit.structure("Paths", "Ground")
	for line: Array in PATHS:
		for i in line.size() - 1:
			_path_segment(roads, line[i], line[i + 1])
	# Outside the fences: the motorway to the east, the boulevard to the south.
	kit.box(roads, 211, 10, 220, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)
	kit.box(roads, 0, 213, 211, 220, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


## A strip of asphalt between two plan points, a little wider than the path so
## the corners join.
func _path_segment(s: MapKit.Structure, a: Vector2, b: Vector2) -> void:
	var half := PATH_WIDTH / 2.0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half
	kit.box(s, lo.x, lo.y, hi.x, hi.y, 0, PATH_HEIGHT, MAT_ASPHALT, MapKit.Kind.GHOST)


func _build_borders() -> void:
	# North: railway embankment, crossed by the exit tunnel (closed until S-007).
	var rail := kit.structure("Embankment")
	kit.box(rail, 0, 0, 150, 10, 0, 6, MAT_OBSTACLE)
	kit.box(rail, 160, 0, 220, 10, 0, 6, MAT_OBSTACLE)
	kit.box(rail, 150, 0, 160, 10, 3.6, 6, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.box(rail, 0, 1, 220, 2, 6, 6.6, MAT_OBSTACLE, MapKit.Kind.GHOST)  # Track ballast.
	var tunnel := kit.structure("ExitTunnel")
	kit.box(tunnel, 149.5, 10, 150.5, 12, 0, 6, MAT_CONCRETE)
	kit.box(tunnel, 159.5, 10, 160.5, 12, 0, 6, MAT_CONCRETE)
	kit.box(tunnel, 150, 10, 160, 12, 3.6, 6, MAT_CONCRETE, MapKit.Kind.FLOOR)
	# The grille closing the tunnel is the ExitGate, a node of its own (S-007).
	# Past the north mouth, out of the cité: an invisible wall, the hunted who
	# gets there is already out (ExitZone).
	kit.box(tunnel, 150, -0.5, 160, 0, 0, 6, null)
	# East: noise wall along the motorway.
	var east := kit.structure("NoiseWall")
	kit.box(east, 210, 10, 210.5, 220, 0, 5, MAT_CONCRETE)
	# South: site fences across the boulevard. West: wasteland fence.
	var south := kit.structure("SiteFence")
	kit.box(south, 6, 212, 210, 212.2, 0, 2.2, _material("fence"))
	var west := kit.structure("WastelandFence")
	kit.box(west, 6, 10, 6.1, 212.2, 0, 2.2, _material("fence"))


# --- Blocks of flats --------------------------------------------------------


func _build_facades() -> void:
	for facade_name: String in FACADES:
		var rect: Rect2 = FACADES[facade_name][0]
		var height: float = FACADES[facade_name][1] * STOREY
		var porch: Variant = FACADES[facade_name][2]
		var s := kit.structure(facade_name)
		var y0 := rect.position.y
		var y1 := rect.end.y
		if porch == null:
			kit.box(s, rect.position.x, y0, rect.end.x, y1, 0, height, MAT_CONCRETE)
			continue
		kit.box(s, rect.position.x, y0, porch.x, y1, 0, height, MAT_CONCRETE)
		kit.box(s, porch.y, y0, rect.end.x, y1, 0, height, MAT_CONCRETE)
		kit.box(s, porch.x, y0, porch.y, y1, PORCH_HEIGHT, height, MAT_CONCRETE, MapKit.Kind.FLOOR)


# --- Visitable buildings (Q3) -----------------------------------------------


func _build_tower() -> void:
	var s := kit.structure("Tower")
	var r := TOWER
	var inner := r.grow(-WALL)
	var top := TOWER_VISITED_STOREYS * STOREY
	var east := STAIR_X + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var flights_north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH
	var stair_north := flights_north - STAIR_MID_LANDING
	var hole := Rect2(STAIR_X, stair_north, east - STAIR_X, STAIR_LANDING_Y - stair_north)
	# Upper mass, seen from the whole cité, with its red light on top.
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, top, TOWER_STOREYS * STOREY, MAT_CONCRETE)
	for level in TOWER_VISITED_STOREYS:
		var h := level * STOREY
		var windows: Array = [] if level == 0 else _windows(r.position.x, r.end.x, h)
		# Outer walls: double doors north and south on the ground floor (S-016).
		var north_gaps: Array = [[TOWER_NORTH_DOORS.x, TOWER_NORTH_DOORS.y, DOOR_TOP]] if level == 0 else windows
		var south_gaps: Array = [[TOWER_SOUTH_DOORS.x, TOWER_SOUTH_DOORS.y, DOOR_TOP]] if level == 0 else windows
		kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, north_gaps)
		kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, south_gaps)
		var side: Array = [] if level == 0 else _windows(r.position.y, r.end.y, h)
		kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, side)
		# East: the fire escape door at the end of each corridor (S-016, Q4).
		var east_gaps := side.duplicate()
		if level > 0:
			east_gaps.append([FIRE_ESCAPE_DOOR.x, FIRE_ESCAPE_DOOR.y, h + DOOR_TOP])
		kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, h, h + STOREY, WALL, MAT_CONCRETE, east_gaps)
		# Floor: the ground floor stands on the ground, the others have a hole for the stairs.
		if level > 0:
			for piece in MapKit.subtract(inner, hole):
				kit.box(s, piece.position.x, piece.position.y, piece.end.x, piece.end.y, h - SLAB, h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
		else:
			for piece in MapKit.subtract(inner, CELLAR_STAIRS):
				kit.box(s, piece.position.x, piece.position.y, piece.end.x, piece.end.y, 0, 0.03, MAT_OBSTACLE, MapKit.Kind.GHOST)
		_tower_stairs(s, h, level == TOWER_VISITED_STOREYS - 1)
		# On each storey, a double fire door across the corridor on either side
		# of the stair landing (Q3), a lintel above it.
		if level > 0:
			for x: float in [STAIR_X - WALL / 2, east + WALL / 2]:
				var leaf := (CORRIDOR.y - CORRIDOR.x) / 2.0
				kit.box(s, x - WALL / 2, CORRIDOR.x, x + WALL / 2, CORRIDOR.y, h + DOOR_TOP, h + STOREY, MAT_CONCRETE)
				_door(Vector3(x, h, CORRIDOR.x + leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
				_door(Vector3(x, h, CORRIDOR.y - leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
		if level == 0:
			_tower_ground_floor(s)
		else:
			_tower_flats(s, h)
			_door(Vector3(r.end.x - WALL / 2, h, (FIRE_ESCAPE_DOOR.x + FIRE_ESCAPE_DOOR.y) / 2.0), 90.0, FIRE_ESCAPE_DOOR.y - FIRE_ESCAPE_DOOR.x, Door.Kind.FIRE)
	# Stairwell walls, west, east and north, from the ground to the top.
	kit.wall_y(s, stair_north - WALL, STAIR_LANDING_Y, STAIR_X - WALL / 2, 0, top, WALL, MAT_CONCRETE)
	kit.wall_y(s, stair_north - WALL, STAIR_LANDING_Y, east + WALL / 2, 0, top, WALL, MAT_CONCRETE)
	kit.wall_x(s, STAIR_X - WALL, east + WALL, stair_north - WALL / 2, 0, top, WALL, MAT_CONCRETE)
	# The lift shaft, beside the stairs, from the ground to the top: its cabin
	# is stuck on the ground floor (a hiding spot, S-016).
	kit.box(s, LIFT_SHAFT.position.x, LIFT_SHAFT.position.y, LIFT_SHAFT.end.x, LIFT_SHAFT.end.y, 0, top, MAT_CONCRETE)
	_tower_fire_escape(s)
	var beacon := _material("beacon")
	var c := r.get_center()
	kit.box(s, c.x - 0.3, c.y - 0.3, c.x + 0.3, c.y + 0.3, TOWER_STOREYS * STOREY, TOWER_STOREYS * STOREY + 0.6, beacon, MapKit.Kind.GHOST)


## One storey of stairs: flight up to the north, mid landing, flight back south.
## On the last visitable storey a grille closes the way up (Q4).
func _tower_stairs(s: MapKit.Structure, h: float, last: bool) -> void:
	_switchback(s, STAIR_X, h, MAT_OBSTACLE, MAT_CONCRETE)
	if last:
		var west_end := STAIR_X + STAIR_FLIGHT_WIDTH
		kit.box(s, STAIR_X, STAIR_LANDING_Y - 0.15, west_end, STAIR_LANDING_Y, h, h + STOREY, _material("grille"))


## Two flights side by side from x0, the landing to the south on STAIR_LANDING_Y:
## up to the north on the west one, a mid landing, back south on the east one.
func _switchback(s: MapKit.Structure, x0: float, h: float, steps: Material, divider: Material) -> void:
	var half := STOREY / 2.0
	var west_end := x0 + STAIR_FLIGHT_WIDTH
	var east_start := west_end + STAIR_DIVIDER
	var east := east_start + STAIR_FLIGHT_WIDTH
	var north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH
	kit.ramp(s, x0, STAIR_LANDING_Y, west_end, north, h, h + half, false, steps)
	kit.box(s, x0, north - STAIR_MID_LANDING, east, north, h + half - SLAB, h + half, steps, MapKit.Kind.FLOOR)
	kit.ramp(s, east_start, north, east, STAIR_LANDING_Y, h + half, h + STOREY, false, steps)
	kit.box(s, west_end, north, east_start, STAIR_LANDING_Y, h, h + STOREY, divider)


## Ground floor (S-016): a hall through the tower, the stairs down to the
## cellars where the technical room was, the bin room, the stuck lift.
func _tower_ground_floor(s: MapKit.Structure) -> void:
	var r := TOWER
	# Double doors north and south.
	for doors: Vector2 in [TOWER_NORTH_DOORS, TOWER_SOUTH_DOORS]:
		var y := r.position.y + WALL / 2 if doors == TOWER_NORTH_DOORS else r.end.y - WALL / 2
		var leaf := (doors.y - doors.x) / 2.0
		_door(Vector3(doors.x + leaf / 2.0, 0, y), 0.0, leaf)
		_door(Vector3(doors.y - leaf / 2.0, 0, y), 0.0, leaf)
	# Cellar stairs room, north-west: a fire door from the hall.
	var door := CELLAR_DOOR
	kit.wall_y(s, r.position.y, STAIR_LANDING_Y, 99.0, 0, STOREY, WALL, MAT_CONCRETE, [[door.x, door.y, DOOR_TOP]])
	kit.wall_x(s, r.position.x, 99.0, STAIR_LANDING_Y, 0, STOREY, WALL, MAT_CONCRETE)
	_door(Vector3(99.0, 0, (door.x + door.y) / 2.0), 90.0, door.y - door.x, Door.Kind.FIRE)
	# A railing along the open side of the stairs, but at their top.
	var c := CELLAR_STAIRS
	kit.wall_x(s, c.position.x + CELLAR_LANDING, c.end.x, c.position.y - 0.1, 0, PARAPET, 0.2, MAT_CONCRETE)
	kit.wall_y(s, c.position.y - 0.2, c.end.y, c.end.x + 0.1, 0, PARAPET, 0.2, MAT_CONCRETE)
	# Bin room, south-west, with its door.
	kit.wall_x(s, r.position.x, 99.0, 104.0, 0, STOREY, WALL, MAT_CONCRETE, [[95.0, 96.2, DOOR_TOP]])
	_door(Vector3(95.6, 0, 104.0), 0.0, 1.2)
	kit.wall_y(s, 104.0, r.end.y, 99.0, 0, STOREY, WALL, MAT_CONCRETE)
	# Letter boxes along the east wall of the hall.
	kit.box(s, 114.6, 92.0, 115.7, 97.0, 0.8, 1.8, MAT_OBSTACLE, MapKit.Kind.FLOOR)


## Flats around the corridor (S-016): all four open on every storey, each
## behind its door, with two or three rooms; a hole in the partition joins
## the two south flats, low enough to crawl through.
func _tower_flats(s: MapKit.Structure, h: float) -> void:
	var r := TOWER
	var top := h + STOREY
	var north := CORRIDOR.x
	var south := CORRIDOR.y
	var stair_east := STAIR_X + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var gap := func(at: float) -> Array:
		return [[at, at + DOOR_WIDTH, h + DOOR_TOP]]
	# Front doors: 0 north-west, 1 north-east, 2 south-west, 3 south-east.
	var fronts := [[97.0, north], [108.0, north], [98.5, south], [106.0, south]]
	kit.wall_x(s, r.position.x, STAIR_X - WALL, north, h, top, WALL, MAT_CONCRETE, gap.call(97.0))
	kit.wall_x(s, stair_east + WALL, r.end.x, north, h, top, WALL, MAT_CONCRETE, gap.call(108.0))
	kit.wall_x(s, r.position.x, 104.0, south, h, top, WALL, MAT_CONCRETE, gap.call(98.5))
	kit.wall_x(s, 104.0, r.end.x, south, h, top, WALL, MAT_CONCRETE, gap.call(106.0))
	for front: Array in fronts:
		_door(Vector3(front[0] + DOOR_WIDTH / 2.0, h, front[1]), 0.0, DOOR_WIDTH)
	# Between the south flats, a hole to crawl through (Q4).
	var crawl := TOWER_CRAWL_HOLE
	kit.wall_y(s, south, r.end.y, 104.0, h, top, WALL, MAT_CONCRETE, [[crawl.x, crawl.y, h + TOWER_CRAWL_HEIGHT]])
	# North flats end at the stairwell.
	kit.wall_y(s, r.position.y, north, STAIR_X - WALL / 2, h, top, WALL, MAT_CONCRETE)
	kit.wall_y(s, r.position.y, north, stair_east + WALL / 2, h, top, WALL, MAT_CONCRETE)
	# Inside each flat, a partition with a doorway between two rooms, and a
	# bathroom wall in the south flats.
	kit.wall_y(s, r.position.y, north, 96.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]])
	kit.wall_y(s, r.position.y, north, 111.0, h, top, WALL, MAT_CONCRETE, [[93.0, 94.2, h + DOOR_TOP]])
	kit.wall_x(s, r.position.x, 104.0, 107.0, h, top, WALL, MAT_CONCRETE, [[100.0, 101.2, h + DOOR_TOP]])
	kit.wall_x(s, 104.0, r.end.x, 107.0, h, top, WALL, MAT_CONCRETE, [[107.0, 108.2, h + DOOR_TOP]])
	kit.wall_y(s, 107.0, r.end.y, 98.0, h, top, WALL, MAT_CONCRETE, [[108.0, 109.2, h + DOOR_TOP]])
	kit.wall_y(s, 107.0, r.end.y, 110.0, h, top, WALL, MAT_CONCRETE, [[108.0, 109.2, h + DOOR_TOP]])


## Metal stairs outside the east wall, from the ground to the 4th storey
## (S-016, Q4 and Q9), with a landing at each corridor door.
func _tower_fire_escape(s: MapKit.Structure) -> void:
	var metal := _material("metal")
	var x0 := TOWER.end.x + 0.3
	var east := x0 + 2 * STAIR_FLIGHT_WIDTH + STAIR_DIVIDER
	var landing_south := CORRIDOR.y
	var north := STAIR_LANDING_Y - STAIR_FLIGHT_LENGTH - STAIR_MID_LANDING
	for level in TOWER_VISITED_STOREYS:
		var h := level * STOREY
		if level > 0:
			kit.box(s, TOWER.end.x, STAIR_LANDING_Y, east, landing_south, h - SLAB, h, metal, MapKit.Kind.FLOOR)
			kit.wall_x(s, x0, east, landing_south + 0.05, h, h + PARAPET, 0.1, metal)
		if level < TOWER_VISITED_STOREYS - 1:
			_switchback(s, x0, h, metal, metal)
		# Railings on the outer sides of the flights.
		kit.wall_y(s, north, landing_south, east + 0.05, h, h + STOREY if level < TOWER_VISITED_STOREYS - 1 else h + PARAPET, 0.1, metal)
		kit.wall_x(s, x0, east, north - 0.05, h, h + PARAPET + STOREY / 2.0, 0.1, metal)
	var floor_box := MetalFloor.new()
	floor_box.name = "FireEscapeMetal"
	floor_box.size = Vector3(east - TOWER.end.x, TOWER_VISITED_STOREYS * STOREY + 2.0, landing_south - north)
	floor_box.position = kit.world((TOWER.end.x + east) / 2.0, (north + landing_south) / 2.0, floor_box.size.y / 2.0 - 1.0)
	_metal_floors.append(floor_box)


## The cellars (S-016, Q5): stairs down from the tower's ground floor, then a
## corridor under the street to the car park, a fire door at each end, the
## cellar cages along it.
func _build_cellars() -> void:
	var s := kit.structure("Cellars")
	var c := CELLAR_STAIRS
	var corridor := CELLAR_CORRIDOR
	var floor_h := -CAR_PARK_DEPTH
	var ceiling := -GROUND_THICKNESS
	# Stairs down from the west (top) to the east (bottom), in their shaft,
	# after a flat landing at the top: turning onto a slope at once, an AI
	# body caught on the shaft's edge there and stayed (T-243).
	var landing := c.position.x + CELLAR_LANDING
	kit.box(s, c.position.x, c.position.y, landing, c.end.y, -SLAB, 0, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.ramp(s, landing, c.position.y, c.end.x, c.end.y, 0, floor_h, true, MAT_OBSTACLE)
	kit.wall_x(s, c.position.x, c.end.x, c.position.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(s, c.position.y - WALL, corridor.end.y + WALL, c.position.x - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	# The corridor, from the foot of the stairs to the car park.
	kit.box(s, c.end.x, corridor.position.y, corridor.end.x, corridor.end.y, floor_h - SLAB, floor_h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.wall_x(s, c.end.x, corridor.end.x, corridor.position.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE, [[CELLAR_CAGES.x, CELLAR_CAGES.y, ceiling]])
	kit.wall_x(s, c.position.x - WALL, corridor.end.x, corridor.end.y + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	var mid := (corridor.position.y + corridor.end.y) / 2.0
	for x: float in CELLAR_FIRE_DOORS:
		kit.wall_y(s, corridor.position.y - WALL, corridor.end.y + WALL, x, -CAR_PARK_DEPTH + DOOR_TOP, ceiling, WALL, MAT_CONCRETE)
		var leaf := corridor.size.y / 2.0
		_door(Vector3(x, floor_h, mid - leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
		_door(Vector3(x, floor_h, mid + leaf / 2.0), 90.0, leaf, Door.Kind.FIRE)
	# Cellar cages in an alcove north of the corridor: grilles, boxes inside,
	# the middle one left open.
	var cages := CELLAR_CAGES
	var back := corridor.position.y - CELLAR_CAGE_DEPTH
	var grille := _material("grille")
	kit.box(s, cages.x, back, cages.y, corridor.position.y, floor_h - SLAB, floor_h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.wall_x(s, cages.x, cages.y, back - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	var cage := 3.0
	var count := roundi((cages.y - cages.x) / cage)
	for i in count + 1:
		var x := cages.x + i * cage
		kit.box(s, x - 0.03, back, x + 0.03, corridor.position.y, floor_h, ceiling, grille)
	for i in count:
		var x := cages.x + i * cage
		# Boxes at the back; in a prison cage, pushed west, out of the way.
		var junk := 0.2 if i in PRISON_CAGES else 0.4
		kit.box(s, x + junk, back + 0.1, x + junk + 0.8 + (0.2 if junk > 0.3 else 0.0), back + 0.7, floor_h, floor_h + 0.8, MAT_OBSTACLE, MapKit.Kind.FLOOR)
		if i in PRISON_CAGES:
			# A prison cage (S-018): its gate is the Cage entity.
			kit.box(s, x, corridor.position.y - 0.05, x + cage - PRISON_GATE_WIDTH, corridor.position.y, floor_h, ceiling, grille, MapKit.Kind.FLOOR)
			_cages.append(Vector3(x + cage - PRISON_GATE_WIDTH / 2.0, floor_h, corridor.position.y - 0.025))
		elif i != count / 2:
			kit.box(s, x, corridor.position.y - 0.05, x + cage, corridor.position.y, floor_h, ceiling, grille, MapKit.Kind.FLOOR)


## Records a door to place once the structures are built (S-016): at a plan
## point (x, height, y), its leaf turned by yaw degrees (0: across X).
func _door(at: Vector3, yaw: float, width: float, kind := Door.Kind.NORMAL, bell := false) -> void:
	_doors.append([at, yaw, width, kind, bell])


## Whether a door stands between two rooms of a visited building: a meter
## each side of it is inside one (T-244).
func _is_inner_door(at: Vector3, yaw: float) -> bool:
	var across := Vector2(0, 1) if is_zero_approx(fmod(yaw, 180.0)) else Vector2(1, 0)
	for side: float in [-1.0, 1.0]:
		var point := Vector2(at.x, at.z) + across * side
		if not _in_building(point, at.y + 1.0):
			return false
	return true


## Whether a plan point at this height is inside a visited building.
func _in_building(point: Vector2, h: float) -> bool:
	var data := _buildings()
	var extras := _extra_boxes()
	for building_name: String in data:
		var entry: Array = data[building_name]
		var boxes: Array = [[entry[0], entry[1], entry[2]]] + extras.get(building_name, [])
		for box: Array in boxes:
			if (box[0] as Rect2).has_point(point) and h > box[1] and h < box[2]:
				return true
	return false


## The doors and the metal floors. Doors are not navigation sources: the
## navigation mesh goes through their doorways, except for the emergency
## exits, which the AIs could not open from outside.
func _add_doors() -> void:
	var doors := _group("Doors")
	var exits := Node3D.new()
	exits.name = "EmergencyExits"
	exits.add_to_group("navigation_source", true)
	doors.add_child(exits)
	exits.owner = _root
	var count := 0
	for entry: Array in _doors:
		var door: Door = DOOR.instantiate()
		count += 1
		door.name = "Door%d" % count
		var at: Vector3 = entry[0]
		door.position = kit.world(at.x, at.z, at.y)
		door.rotation_degrees.y = entry[1]
		door.width = entry[2]
		door.kind = entry[3]
		door.bell = entry[4]
		door.indoor = _is_inner_door(at, entry[1])
		var parent := exits if door.kind == Door.Kind.EMERGENCY else doors
		parent.add_child(door)
		door.owner = _root
	_add_prison()
	_add_network()
	var metal := _group("MetalFloors")
	for floor_box in _metal_floors:
		metal.add_child(floor_box)
		floor_box.owner = _root


## The network of the cité (S-018): its terminals (their desks are navigation
## sources), its cameras, loudspeakers and metal shutters (not navigation
## sources: the mesh goes under a shutter, the AIs see it down on their way).
func _add_network() -> void:
	var network := Node.new()
	network.name = "Network"
	network.set_script(NETWORK_SCRIPT)
	_add(network)
	var desks := Node3D.new()
	desks.name = "Terminals"
	desks.add_to_group("navigation_source", true)
	network.add_child(desks)
	desks.owner = _root
	var terminals_list: Array = TERMINALS + Hospital.TERMINALS  # S-014.
	for i in terminals_list.size():
		var entry: Array = terminals_list[i]
		var terminal: Terminal = TERMINAL.instantiate()
		terminal.name = "Terminal%d" % (i + 1)
		var at: Vector3 = entry[0]
		terminal.position = kit.world(at.x, at.z, at.y)
		terminal.rotation_degrees.y = entry[1]
		terminal.kind = entry[2]
		terminal.label_key = entry[3]
		desks.add_child(terminal)
		terminal.owner = _root
	var cameras := Node3D.new()
	cameras.name = "Cameras"
	network.add_child(cameras)
	cameras.owner = _root
	var cameras_list: Array = CAMERAS + Hospital.CAMERAS  # S-014.
	for i in cameras_list.size():
		var entry: Array = cameras_list[i]
		var camera: SecurityCamera = SECURITY_CAMERA.instantiate()
		camera.name = "Camera%d" % (i + 1)
		var at: Vector3 = entry[0]
		var target: Vector3 = entry[1]
		var from := kit.world(at.x, at.z, at.y)
		var to := kit.world(target.x, target.z, target.y)
		camera.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
		camera.label_key = entry[2]
		cameras.add_child(camera)
		camera.owner = _root
	var speakers := Node3D.new()
	speakers.name = "Loudspeakers"
	network.add_child(speakers)
	speakers.owner = _root
	var speakers_list: Array = SPEAKERS + Hospital.SPEAKERS  # S-014.
	for i in speakers_list.size():
		var entry: Array = speakers_list[i]
		var speaker: Node3D = LOUDSPEAKER.instantiate()
		speaker.name = "Loudspeaker%d" % (i + 1)
		var at: Vector3 = entry[0]
		speaker.position = kit.world(at.x, at.z, at.y)
		speaker.rotation_degrees.y = entry[1]
		speaker.set("label_key", entry[2])
		speakers.add_child(speaker)
		speaker.owner = _root
	var shutters := Node3D.new()
	shutters.name = "Shutters"
	network.add_child(shutters)
	shutters.owner = _root
	for i in SHUTTERS.size():
		var entry: Array = SHUTTERS[i]
		var shutter: Node3D = REMOTE_SHUTTER.instantiate()
		shutter.name = "Shutter%d" % (i + 1)
		var at: Vector3 = entry[0]
		shutter.position = kit.world(at.x, at.z, at.y)
		shutter.rotation_degrees.y = entry[1]
		shutter.set("width", entry[2])
		shutter.set("height", entry[3])
		shutter.set("label_key", entry[4])
		shutters.add_child(shutter)
		shutter.owner = _root


## The prison (S-018, Q1): a Cage in each prison cage's grille. Not a
## navigation source: the mesh goes into the cages through their gates.
func _add_prison() -> void:
	var prison := Node3D.new()
	prison.name = "Prison"
	prison.set_script(PRISON_SCRIPT)
	prison.set("settings", PRISON_SETTINGS)
	_add(prison)
	for i in _cages.size():
		var cage: Node3D = CAGE.instantiate()
		cage.name = "Cage%d" % (i + 1)
		var at := _cages[i]
		cage.position = kit.world(at.x, at.z, at.y)
		prison.add_child(cage)
		cage.owner = _root


## Window openings of a storey at height h, one every WINDOW_STEP meters.
func _windows(from: float, to: float, h: float) -> Array:
	var gaps: Array = []
	var at := from + WINDOW_INSET
	while at + WINDOW_WIDTH <= to:
		gaps.append([at, at + WINDOW_WIDTH, h + WINDOW_TOP, h + WINDOW_SILL])
		at += WINDOW_STEP
	return gaps


func _build_social_centre() -> void:
	var s := kit.structure("SocialCentre")
	var r := SOCIAL_CENTRE
	var h := SOCIAL_CENTRE_HEIGHT
	var hall_east := 160.0
	var office_west := 163.0
	var kitchen := CENTRE_KITCHEN
	# Outer walls (S-016, Q4): entrances north (corridor) and west (great hall),
	# the emergency exit at the south end of the corridor, the kitchen's back
	# door, windows.
	var north := CENTRE_NORTH_DOORS
	var west := CENTRE_WEST_DOORS
	var exit := CENTRE_EMERGENCY_EXIT
	var back := CENTRE_KITCHEN_DOOR
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, 0, h, WALL, MAT_CONCRETE, [[north.x, north.y, DOOR_TOP], [144.0, 146.0, 2.4, 1.0], [150.0, 152.0, 2.4, 1.0], [166.0, 168.0, 2.4, 1.0], [172.0, 174.0, 2.4, 1.0]])
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[144.0, 146.0, 2.4, 1.0], [152.0, 154.0, 2.4, 1.0], [back.x, back.y, DOOR_TOP], [exit.x, exit.y, DOOR_TOP], [168.0, 170.0, 2.4, 1.0]])
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE, [[west.x, west.y, DOOR_TOP]])
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[64.0, 65.5, 2.4, 1.0], [72.0, 73.5, 2.4, 1.0], [80.0, 81.5, 2.4, 1.0]])
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, h, h + SLAB, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	_double_door(Vector3((north.x + north.y) / 2.0, 0, r.position.y + WALL / 2), 0.0, north.y - north.x)
	_double_door(Vector3(r.position.x + WALL / 2, 0, (west.x + west.y) / 2.0), 90.0, west.y - west.x)
	_door(Vector3((exit.x + exit.y) / 2.0, 0, r.end.y - WALL / 2), 0.0, exit.y - exit.x, Door.Kind.EMERGENCY)
	_door(Vector3((back.x + back.y) / 2.0, 0, r.end.y - WALL / 2), 0.0, back.y - back.x)
	# Great hall and corridor, double doors between them.
	var hall_doors := [Vector2(66.0, 68.0), Vector2(73.0, 75.0)]
	var hall_gaps: Array = []
	for d: Vector2 in hall_doors:
		hall_gaps.append([d.x, d.y, DOOR_TOP])
		_double_door(Vector3(hall_east, 0, (d.x + d.y) / 2.0), 90.0, d.y - d.x)
	hall_gaps.append([80.0, 81.2, DOOR_TOP])  # The kitchen, from the corridor.
	_door(Vector3(hall_east, 0, 80.6), 90.0, 1.2)
	kit.wall_y(s, r.position.y, r.end.y, hall_east, 0, h, WALL, MAT_CONCRETE, hall_gaps)
	# Offices along the corridor, each with its door, and a door between
	# neighbours: no dead end (Q4).
	var office_gaps: Array = []
	for y: float in [63.0, 71.0, 79.0]:
		office_gaps.append([y, y + 1.2, DOOR_TOP])
		_door(Vector3(office_west, 0, y + 0.6), 90.0, 1.2)
	kit.wall_y(s, r.position.y, r.end.y, office_west, 0, h, WALL, MAT_CONCRETE, office_gaps)
	for y: float in [68.0, 76.0]:
		kit.wall_x(s, office_west, r.end.x, y, 0, h, WALL, MAT_CONCRETE, [[172.0, 173.2, DOOR_TOP]])
		_door(Vector3(172.6, 0, y), 0.0, 1.2)
	# The kitchen, south-east of the great hall: a door to the hall, a hatch
	# over the counter.
	kit.wall_x(s, kitchen.position.x, kitchen.end.x, kitchen.position.y, 0, h, WALL, MAT_CONCRETE, [[154.0, 156.4, 2.0, 1.0]])
	kit.wall_y(s, kitchen.position.y, r.end.y, kitchen.position.x, 0, h, WALL, MAT_CONCRETE, [[80.0, 81.2, DOOR_TOP]])
	_door(Vector3(kitchen.position.x, 0, 80.6), 90.0, 1.2)
	kit.box(s, 154.0, kitchen.position.y + WALL / 2, 156.4, kitchen.position.y + 0.8, 0, 1.0, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# The stage, west of the hall, its wings behind a curtain.
	var stage := CENTRE_STAGE
	kit.box(s, stage.position.x, stage.position.y, stage.end.x, stage.end.y, 0, 0.6, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# Tables in the hall, desks in the offices (the stacked chairs: FURNITURE).
	for t: Vector2 in [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]:
		kit.box(s, t.x - 1.0, t.y - 0.5, t.x + 1.0, t.y + 0.5, 0, 0.75, null, MapKit.Kind.FLOOR)
	for d: Vector2 in [Vector2(172, 64), Vector2(172, 72), Vector2(172, 80)]:
		kit.box(s, d.x - 0.8, d.y - 0.4, d.x + 0.8, d.y + 0.4, 0, 0.75, null, MapKit.Kind.FLOOR)


## Two leaves meeting in the middle of a doorway this wide.
func _double_door(at: Vector3, yaw: float, width: float, kind := Door.Kind.NORMAL) -> void:
	var leaf := width / 2.0
	var along := Vector3(leaf / 2.0, 0, 0) if is_zero_approx(yaw) else Vector3(0, 0, leaf / 2.0)
	_door(at - along, yaw, leaf, kind)
	_door(at + along, yaw, leaf, kind)


func _build_gallery() -> void:
	var s := kit.structure("Gallery")
	var r := GALLERY
	var h := GALLERY_HEIGHT
	var front := r.position.y + GALLERY_ARCADE_DEPTH
	var back := r.end.y - GALLERY_BACK_CORRIDOR
	var width := r.size.x / GALLERY_SHOPS
	var corridor := Vector2(back + 0.2, r.end.y - 0.3)
	# Arcade roof on pillars.
	kit.box(s, r.position.x, r.position.y, r.end.x, front, h - SLAB, h, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	var x := r.position.x + 0.3
	while x < r.end.x:
		kit.box(s, x - 0.2, r.position.y + 0.1, x + 0.2, r.position.y + 0.5, 0, h - SLAB, MAT_CONCRETE)
		x += width
	kit.box(s, r.end.x - 0.5, r.position.y + 0.1, r.end.x - 0.1, r.position.y + 0.5, 0, h - SLAB, MAT_CONCRETE)
	# Shop fronts (S-016): the pharmacy's door, the laundrette's double door,
	# the tobacconist's shutter to roll up, the grocer's shutter half down, the
	# baker's door with its bell.
	var fronts: Array = []
	for i in GALLERY_SHOPS:
		var gap: Vector2 = GALLERY_FRONTS[i]
		var top := SHUTTER_TOP if i == GALLERY_HALF_SHUTTER else DOOR_TOP
		fronts.append([gap.x, gap.y, top])
	kit.wall_x(s, r.position.x, r.end.x, front, 0, h, WALL, MAT_CONCRETE, fronts)
	var mid := func(i: int) -> Vector3:
		return Vector3((GALLERY_FRONTS[i].x + GALLERY_FRONTS[i].y) / 2.0, 0, front)
	var span := func(i: int) -> float:
		return GALLERY_FRONTS[i].y - GALLERY_FRONTS[i].x
	_door(mid.call(0), 0.0, span.call(0))
	_double_door(mid.call(1), 0.0, span.call(1))
	_door(mid.call(2), 0.0, span.call(2), Door.Kind.SHUTTER)
	_door(mid.call(4), 0.0, span.call(4), Door.Kind.NORMAL, true)
	# Back wall, east and west walls, roof. The delivery corridor opens at
	# both ends: a fire door east, an emergency exit west (Q4).
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_y(s, front, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE, [[corridor.x, corridor.y, DOOR_TOP]])
	kit.wall_y(s, front, r.end.y, r.end.x - WALL / 2, 0, h, WALL, MAT_CONCRETE, [[corridor.x, corridor.y, DOOR_TOP]])
	var corridor_mid := (corridor.x + corridor.y) / 2.0
	_door(Vector3(r.end.x - WALL / 2, 0, corridor_mid), 90.0, corridor.y - corridor.x, Door.Kind.FIRE)
	_door(Vector3(r.position.x + WALL / 2, 0, corridor_mid), -90.0, corridor.y - corridor.x, Door.Kind.EMERGENCY)
	kit.box(s, r.position.x, front, r.end.x, r.end.y, h, h + SLAB, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	# Shops side by side, each with a back door onto the corridor; a door
	# between the grocer's and the baker's stockrooms.
	for i in range(1, GALLERY_SHOPS):
		var gaps: Array = []
		if i == GALLERY_SHOPS - 1:
			gaps.append([144.5, 145.7, DOOR_TOP])
			_door(Vector3(r.position.x + i * width, 0, 145.1), 90.0, 1.2)
		kit.wall_y(s, front, back, r.position.x + i * width, 0, h, WALL, MAT_CONCRETE, gaps)
	var back_doors: Array = []
	for i in GALLERY_SHOPS:
		var at := r.position.x + i * width + 5.5
		back_doors.append([at, at + 1.2, DOOR_TOP])
		_door(Vector3(at + 0.6, 0, back), 0.0, 1.2)
	kit.wall_x(s, r.position.x, r.end.x, back, 0, h, WALL, MAT_CONCRETE, back_doors)
	# Washing machines along the laundrette walls.
	var laundrette := r.position.x + width
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		kit.box(s, mx - 0.6, back - 1.0, mx + 0.6, back - 0.2, 0, 0.9, null, MapKit.Kind.FLOOR)
	# Counters and shelves: FURNITURE (T-241).
	_gallery_roof_stairs(s)


## Two steep metal flights up to the roof (S-016, Q4: they stand for the
## ladders), one behind the back wall, one along the east wall.
func _gallery_roof_stairs(s: MapKit.Structure) -> void:
	var r := GALLERY
	var metal := _material("metal")
	var roof := GALLERY_HEIGHT + SLAB
	var w := GALLERY_ROOF_STAIR_WIDTH
	# Behind: rising east along the back wall, a landing onto the roof.
	var b := GALLERY_BACK_STAIRS
	kit.ramp(s, b.x, r.end.y, b.y, r.end.y + w, 0, roof, true, metal)
	kit.box(s, b.y, r.end.y, b.y + 1.5, r.end.y + w, roof - SLAB, roof, metal, MapKit.Kind.FLOOR)
	kit.wall_x(s, b.x, b.y + 1.5, r.end.y + w + 0.05, 0, roof + PARAPET, 0.1, metal)
	_metal_floor("GalleryBackStairs", Rect2(b.x, r.end.y, b.y + 1.5 - b.x, w), roof)
	# East: rising south along the east wall, a landing onto the roof.
	var e := GALLERY_EAST_STAIRS
	kit.ramp(s, r.end.x, e.x, r.end.x + w, e.y, 0, roof, false, metal)
	kit.box(s, r.end.x, e.y, r.end.x + w, e.y + 1.5, roof - SLAB, roof, metal, MapKit.Kind.FLOOR)
	kit.wall_y(s, e.x, e.y + 1.5, r.end.x + w + 0.05, 0, roof + PARAPET, 0.1, metal)
	_metal_floor("GalleryEastStairs", Rect2(r.end.x, e.x, w, e.y + 1.5 - e.x), roof)


## A metal floor over a plan rectangle, from the ground to a little above
## the height.
func _metal_floor(node_name: String, rect: Rect2, top: float) -> void:
	var floor_box := MetalFloor.new()
	floor_box.name = node_name
	floor_box.size = Vector3(rect.size.x, top + 2.0, rect.size.y)
	var c := rect.get_center()
	floor_box.position = kit.world(c.x, c.y, floor_box.size.y / 2.0 - 0.5)
	_metal_floors.append(floor_box)


func _build_car_park() -> void:
	var s := kit.structure("CarPark")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ramp := CAR_PARK_RAMP
	var stairs := CAR_PARK_STAIRS
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, floor_h - SLAB, floor_h, MAT_ASPHALT, MapKit.Kind.FLOOR)
	# Retaining walls; the ramp comes in through the west one.
	var ceiling := -GROUND_THICKNESS
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE, [[CELLAR_CORRIDOR.position.y, CELLAR_CORRIDOR.end.y, ceiling], [ramp.position.y, ramp.end.y, ceiling]])
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, floor_h, ceiling, WALL, MAT_CONCRETE)
	# Pillars every 8 m.
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			kit.box(s, px - 0.25, py - 0.25, px + 0.25, py + 0.25, floor_h, ceiling, MAT_CONCRETE)
		px += CAR_PARK_PILLAR_STEP
	# Car ramp from the ground down to the car park, with its side walls.
	kit.ramp(s, ramp.position.x, ramp.position.y, ramp.end.x, ramp.end.y, 0, floor_h, true, MAT_ASPHALT)
	kit.wall_x(s, ramp.position.x, ramp.end.x, ramp.position.y - WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_x(s, ramp.position.x, ramp.end.x, ramp.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	# Emergency stairs up to the slab in the south-east corner, a railing around them.
	kit.ramp(s, stairs.position.x, stairs.position.y, stairs.end.x, stairs.end.y, floor_h, 0, true, MAT_OBSTACLE)
	kit.wall_x(s, stairs.position.x - WALL, stairs.end.x, stairs.position.y - WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_x(s, stairs.position.x - WALL, stairs.end.x, stairs.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_y(s, stairs.position.y, stairs.end.y, stairs.position.x - WALL / 2, 0, PARAPET, WALL, MAT_CONCRETE)
	# North stairs (S-016): from the ground at their west end down to the
	# floor, closed under the flight, a railing around the hole, a fire door
	# at their foot.
	var north := CAR_PARK_NORTH_STAIRS
	kit.ramp(s, north.position.x, north.position.y, north.end.x, north.end.y, 0, floor_h, true, MAT_OBSTACLE)
	kit.wall_x(s, north.position.x, north.end.x + WALL, north.end.y + WALL / 2, floor_h, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_x(s, north.position.x, north.end.x + WALL, north.position.y - WALL / 2, 0, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_y(s, north.position.y, north.end.y, north.end.x + WALL / 2, 0, PARAPET, WALL, MAT_CONCRETE)
	kit.wall_y(s, north.position.y, north.end.y, north.position.x - WALL / 2, floor_h, -GROUND_THICKNESS, WALL, MAT_CONCRETE)
	kit.wall_y(s, north.position.y - WALL, north.end.y + WALL, north.end.x + WALL / 2, floor_h + DOOR_TOP, ceiling, WALL, MAT_CONCRETE)
	_double_door(Vector3(north.end.x + WALL / 2, floor_h, north.get_center().y), 90.0, north.size.y, Door.Kind.FIRE)
	# The technical room, east, with its door.
	var room := CAR_PARK_TECHNICAL
	var room_door := [[104.0, 105.2, floor_h + DOOR_TOP]]
	kit.wall_x(s, room.position.x, room.end.x, room.position.y, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_x(s, room.position.x, room.end.x, room.end.y, floor_h, ceiling, WALL, MAT_CONCRETE)
	kit.wall_y(s, room.position.y, room.end.y, room.position.x, floor_h, ceiling, WALL, MAT_CONCRETE, room_door)
	_door(Vector3(room.position.x, floor_h, 104.6), 90.0, 1.2)
	# Parked wrecks to hide behind.
	for c: Vector2 in CAR_PARK_WRECKS:
		kit.box(s, c.x - 1.0, c.y - 2.1, c.x + 1.0, c.y + 2.1, floor_h, floor_h + 1.3, null, MapKit.Kind.FLOOR)
	# "P" sign at the ramp.
	kit.box(s, 126.6, 99.4, 126.8, 99.6, 0, 2.6, _material("metal"), MapKit.Kind.FLOOR)


func _build_garages() -> void:
	var s := kit.structure("Garages")
	var r := GARAGES
	var h := GARAGE_HEIGHT
	var width := r.size.y / GARAGE_COUNT
	kit.wall_y(s, r.position.y, r.end.y, r.position.x + WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.position.y + WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.wall_x(s, r.position.x, r.end.x, r.end.y - WALL / 2, 0, h, WALL, MAT_CONCRETE)
	kit.box(s, r.position.x, r.position.y, r.end.x, r.end.y, h, h + 0.2, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	var doors: Array = []
	for i in GARAGE_COUNT:
		var y0 := r.position.y + i * width
		if i > 0:
			kit.wall_x(s, r.position.x, r.end.x, y0, 0, h, WALL, MAT_CONCRETE)
		if GARAGES_OPEN.has(i):
			doors.append([y0 + 0.5, y0 + width - 0.5, DOOR_TOP])
			# Junk inside: a workbench and boxes.
			kit.box(s, r.position.x + 0.4, y0 + 0.6, r.position.x + 2.0, y0 + 2.2, 0, 1.0, MAT_OBSTACLE, MapKit.Kind.FLOOR)
	kit.wall_y(s, r.position.y, r.end.y, r.end.x - WALL / 2, 0, h, WALL, _material("garage_door"), doors)


# --- Outdoor landmarks ------------------------------------------------------


func _build_landmarks() -> void:
	_build_playground()
	_build_city_stadium()
	var transformer := kit.structure("Transformer")
	kit.box(transformer, 96, 150, 105, 157, 0, 2.6, null)  # Dressed by its model (T-048).


func _build_playground() -> void:
	var s := kit.structure("Playground")
	var low := MapKit.Kind.FLOOR
	# Low wall around the sand, with a way in on the north and the south sides.
	# Too high for the navigation mesh to climb (T-060): a kerb the bodies cannot
	# step over, but the mesh could, held the AI prey against it for good.
	var kerb := 0.5
	for y: Array in [[70.0, 70.3], [91.7, 92.0]]:
		kit.box(s, 50, y[0], 60, y[1], 0, kerb, MAT_OBSTACLE, low)
		kit.box(s, 61.6, y[0], 72, y[1], 0, kerb, MAT_OBSTACLE, low)
	kit.box(s, 50, 70.3, 50.3, 91.7, 0, kerb, MAT_OBSTACLE, low)
	kit.box(s, 71.7, 70.3, 72, 91.7, 0, kerb, MAT_OBSTACLE, low)
	# Swing posts, climbing frame and slide: only their collisions, the models
	# dress them (T-048).
	for x: float in [57.0, 65.0]:
		kit.box(s, x - 0.1, 79.0, x + 0.1, 79.2, 0, 2.4, null, low)
		kit.box(s, x - 0.1, 81.8, x + 0.1, 82.0, 0, 2.4, null, low)
	kit.box(s, 53, 73, 56, 76, 0, 1.6, null, low)
	kit.ramp(s, 56, 74, 59.5, 75, 1.6, 0.2, true, null, 0.1)


func _build_city_stadium() -> void:
	var s := kit.structure("CityStadium")
	var boards: Material = null  # Only the collisions: the models dress them (T-048).
	var h := 1.1
	# Boards with an opening on the west and the north sides.
	kit.wall_x(s, 148, 178, 180, 0, h, 0.15, boards, [[160, 166, h]])
	kit.wall_x(s, 148, 178, 200, 0, h, 0.15, boards)
	kit.wall_y(s, 180, 200, 148, 0, h, 0.15, boards, [[188, 192, h]])
	kit.wall_y(s, 180, 200, 178, 0, h, 0.15, boards)
	# Goals at both ends.
	for x: float in [149.5, 176.5]:
		kit.box(s, x - 0.06, 188.5, x + 0.06, 188.62, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 191.38, x + 0.06, 191.5, 0, 2, boards, MapKit.Kind.FLOOR)
		kit.box(s, x - 0.06, 188.5, x + 0.06, 191.5, 1.9, 2, boards, MapKit.Kind.GHOST)


# --- Props, lights and gameplay nodes ---------------------------------------


## Scan volumes (Q6) with their lights, and the fuse slots (Q5).
## Each entry: plan rectangle, floor and top heights, lights, fuse slots.
func _buildings() -> Dictionary:
	var tower_top := TOWER_VISITED_STOREYS * STOREY
	var data := {
		"Tower": [TOWER, 0.0, tower_top,
			[[Vector3(104, 2.6, 92), 6.0], [Vector3(96, 8.6, 100), 6.0], [Vector3(112, 14.6, 100), 6.0]],
			[Vector3(113, 0, 89), Vector3(113, 6, 110.5), Vector3(96, 9, 109), Vector3(113, 12, 108),
				Vector3(113, 3, 110.5), Vector3(94, 6, 102.5)]],
		"SocialCentre": [SOCIAL_CENTRE, 0.0, SOCIAL_CENTRE_HEIGHT,
			[[Vector3(151, 3.4, 72), 9.0], [Vector3(161.5, 3.4, 72), 5.0]],
			[Vector3(142, 0, 62), Vector3(176, 0, 62), Vector3(176, 0, 74), Vector3(170, 0, 82),
				Vector3(156, 0, 80.5), Vector3(170, 0, 70.5)]],
		"Gallery": [GALLERY, 0.0, GALLERY_HEIGHT,
			[[Vector3(58, 2.9, 143), 5.0], [Vector3(66, 2.8, 137), 6.0]],
			[Vector3(55, 0, 143), Vector3(61, 0, 145), Vector3(76, 0, 142), Vector3(84, 0, 148),
				Vector3(47.5, 0, 148), Vector3(71, 0, 146)]],
		"CarPark": [CAR_PARK, -CAR_PARK_DEPTH, 0.0,
			[[Vector3(152, -0.6, 106), 7.0], [Vector3(170, -0.6, 106), 7.0]],
			[Vector3(142, -3, 97), Vector3(178, -3, 97), Vector3(142, -3, 115), Vector3(166, -3, 115),
				Vector3(178.5, -3, 111), Vector3(110, -3, 97.2)]],
		"Garages": [GARAGES, 0.0, GARAGE_HEIGHT, [], []],
	}
	# Spec S-014: one volume per level of the hospital.
	for level: Array in Hospital.scan_levels():
		data[level[0]] = level[2]
	return data


## Parts of a building outside its main box (S-016, Q5): plan rectangle,
## floor and top heights. The cellar stairs belong to the tower; the cellar
## corridor, past them, to the car park, up to its ceiling: not the street
## above it.
func _extra_boxes() -> Dictionary:
	var c := CELLAR_STAIRS
	var corridor := CELLAR_CORRIDOR
	var cages := Rect2(CELLAR_CAGES.x, corridor.position.y - CELLAR_CAGE_DEPTH, CELLAR_CAGES.y - CELLAR_CAGES.x, CELLAR_CAGE_DEPTH)
	var under := Rect2(c.end.x, corridor.position.y, corridor.end.x - c.end.x, corridor.size.y)
	var boxes := {
		"Tower": [[c, -CAR_PARK_DEPTH, 0.0]],
		"CarPark": [[under, -CAR_PARK_DEPTH, -GROUND_THICKNESS], [cages, -CAR_PARK_DEPTH, -GROUND_THICKNESS]],
	}
	boxes.merge(Hospital.extra_boxes())
	return boxes


func _add_buildings() -> void:
	var parent := Node3D.new()
	parent.name = "Buildings"
	_add(parent)
	var slots_parent := Node3D.new()
	slots_parent.name = "FuseSlots"
	_add(slots_parent)
	var data := _buildings()
	for building_name: String in data:
		var entry: Array = data[building_name]
		var rect: Rect2 = entry[0]
		var bottom: float = entry[1]
		var top: float = entry[2]
		var building: Node3D = BUILDING.instantiate()
		building.name = building_name
		var center := rect.get_center()
		building.position = kit.world(center.x, center.y, (bottom + top) / 2.0)
		building.set("size", Vector3(rect.size.x, top - bottom, rect.size.y))
		building.set("display_key", "BUILDING_" + building_name.to_snake_case().to_upper())
		var level := Hospital.LEVEL_NAMES.find(building_name)
		if level >= 0:
			building.set("display_key", Hospital.LEVEL_KEYS[level])
			building.set("complex", Hospital.COMPLEX)
		var extras: Array[AABB] = []
		for extra: Array in _extra_boxes().get(building_name, []):
			var r2: Rect2 = extra[0]
			var lo := kit.world(r2.position.x, r2.position.y, extra[1]) - building.position
			extras.append(AABB(lo, Vector3(r2.size.x, extra[2] - extra[1], r2.size.y)))
		building.set("extra_boxes", extras)
		parent.add_child(building)
		building.owner = _root
		for i in entry[3].size():
			var spot: Vector3 = entry[3][i][0]
			var light := OmniLight3D.new()
			light.name = "Light%d" % (i + 1)
			light.light_color = Color(1, 0.96, 0.88)
			light.omni_range = entry[3][i][1]
			building.add_child(light)
			light.owner = _root
			light.position = kit.world(spot.x, spot.z, spot.y) - building.position
		if entry[4].is_empty():
			continue
		var slots := Node3D.new()
		slots.name = Hospital.COMPLEX if level >= 0 else building_name
		slots_parent.add_child(slots)
		slots.owner = _root
		for i in entry[4].size():
			var at: Vector3 = entry[4][i]
			var marker := Marker3D.new()
			marker.name = "Slot%d" % (i + 1)
			marker.position = kit.world(at.x, at.z, at.y)
			marker.add_to_group("fuse_slot", true)
			slots.add_child(marker)
			marker.owner = _root


## The transformer, the grille of the exit and the far end of the tunnel (S-007).
func _add_loop() -> void:
	var transformer := TRANSFORMER_NODE.instantiate()
	transformer.position = kit.world(100.5, 153.5)
	_add(_named(transformer, "TransformerPanel"))
	var gate := AnimatableBody3D.new()
	gate.set_script(EXIT_GATE_SCRIPT)
	gate.set("settings", LOOP_SETTINGS)
	gate.set("rise", EXIT_GATE_HEIGHT)
	var center := EXIT_GATE.get_center()
	gate.position = kit.world(center.x, center.y)
	_add(_named(gate, "ExitGate"))
	var size := Vector3(EXIT_GATE.size.x, EXIT_GATE_HEIGHT, EXIT_GATE.size.y)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	box.material = _material("grille")
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	gate.add_child(mesh)
	mesh.owner = _root
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position.y = size.y / 2.0
	gate.add_child(shape)
	shape.owner = _root
	var zone := Area3D.new()
	zone.set_script(EXIT_ZONE_SCRIPT)
	center = EXIT_ZONE.get_center()
	zone.position = kit.world(center.x, center.y, 2.0)
	_add(_named(zone, "ExitZone"))
	var zone_shape := CollisionShape3D.new()
	zone_shape.name = "CollisionShape3D"
	zone_shape.shape = BoxShape3D.new()
	zone_shape.shape.size = Vector3(EXIT_ZONE.size.x, 4.0, EXIT_ZONE.size.y)
	zone.add_child(zone_shape)
	zone_shape.owner = _root


## A fuse box on the nearest wall of each fuse slot (S-007, Q1). The slot
## marker stays in front of it: it is where the AI prey stands to use the box.
func _place_fuse_boxes() -> void:
	var space := _root.get_world_3d().direct_space_state
	for marker: Node3D in _root.get_node("FuseSlots").find_children("Slot*", "Marker3D"):
		var from := marker.global_position + Vector3.UP * 1.3
		var best: Vector3
		var best_distance := FUSE_BOX_WALL_SEARCH
		var facing := Vector3.BACK
		for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var query := PhysicsRayQueryParameters3D.create(
				from, from + direction * FUSE_BOX_WALL_SEARCH, MapKit.WALLS_LAYER
			)
			var hit := space.intersect_ray(query)
			if hit and from.distance_to(hit.position) < best_distance:
				best_distance = from.distance_to(hit.position)
				best = hit.position
				facing = -direction
		var box: Node3D = FUSE_BOX.instantiate()
		box.name = "FuseBox"
		box.set("building_name", String(marker.get_parent().name))
		marker.add_child(box)
		box.owner = _root
		if best_distance < FUSE_BOX_WALL_SEARCH:
			box.global_position = Vector3(best.x, marker.global_position.y, best.z) + facing * 0.01
		else:
			push_warning("No wall near %s" % marker.get_path())
		box.global_rotation.y = atan2(facing.x, facing.z)


## The relay switches and the post-its of the code (S-018, T-266): each
## switch on the nearest wall of its place, a post-it on the wall behind
## each terminal's desk (not the keypad's).
func _place_objectives() -> void:
	var relays := _group("Relays")
	var relays_list: Array = RELAYS + Hospital.RELAYS  # S-014.
	for i in relays_list.size():
		var entry: Array = relays_list[i]
		var at: Vector3 = entry[0]
		var marker := kit.world(at.x, at.z, at.y)
		var switch: Node3D = RELAY_SWITCH.instantiate()
		switch.name = "Relay%d" % (i + 1)
		switch.set("building_name", entry[1])
		relays.add_child(switch)
		switch.owner = _root
		_snap_to_wall(switch, marker)
	var spots := _group("CodeSpots")
	var count := 0
	for terminal: Terminal in _root.get_node("Network/Terminals").get_children():
		if terminal.kind == Terminal.Kind.CODE:
			continue
		count += 1
		var spot: Node3D = CODE_SPOT.instantiate()
		spot.name = "CodeSpot%d" % count
		spots.add_child(spot)
		spot.owner = _root
		var from := terminal.to_global(Vector3(0.4, 1.4, 0.0))
		var back := -terminal.global_basis.z
		var hit := _root.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + back * 2.0, MapKit.WALLS_LAYER)
		)
		if hit:
			spot.global_position = hit.position - back * 0.01
		else:
			push_warning("No wall behind %s" % terminal.name)
			spot.global_position = from + back * 0.58
		spot.global_rotation.y = terminal.global_rotation.y


## Puts a wall object (origin on the floor, front toward +Z) on the nearest
## wall around a point, facing away from it.
func _snap_to_wall(node: Node3D, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.3
	var best := at
	var best_distance := FUSE_BOX_WALL_SEARCH
	var facing := Vector3.BACK
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(
			from, from + direction * FUSE_BOX_WALL_SEARCH, MapKit.WALLS_LAYER
		)
		var hit := space.intersect_ray(query)
		if hit and from.distance_to(hit.position) < best_distance:
			best_distance = from.distance_to(hit.position)
			best = hit.position
			facing = -direction
	if best_distance >= FUSE_BOX_WALL_SEARCH:
		push_warning("No wall near %s" % node.name)
	node.global_position = Vector3(best.x, at.y, best.z) + facing * 0.01
	node.global_rotation.y = atan2(facing.x, facing.z)


## The hiding spots, obstacles for the navigation mesh, and the pickups (S-008).
func _place_ruses() -> void:
	var spots := _group("Hideouts")
	spots.add_to_group("navigation_source", true)
	for i in CLOSETS.size():
		_place_spot(spots, CLOSET, "Closet%d" % (i + 1), CLOSETS[i])
	for i in DUMPSTERS.size():
		_place_spot(spots, DUMPSTER, "Dumpster%d" % (i + 1), DUMPSTERS[i])
	var families := {"Low": LOW_SPOT, "Makeshift": MAKESHIFT_SPOT, "Metal": METAL_SPOT}
	var counts := {}
	for entry: Array in FAMILY_SPOTS + Hospital.SPOTS:
		counts[entry[0]] = counts.get(entry[0], 0) + 1
		var node_name := "%s%d" % [entry[0], counts[entry[0]]]
		if entry.size() > 2:
			var spot: Node3D = families[entry[0]].instantiate()
			spot.name = node_name
			spots.add_child(spot)
			spot.owner = _root
			var at: Vector3 = entry[1]
			var front: Vector2 = entry[2]
			spot.position = kit.world(at.x, at.z, at.y)
			spot.rotation.y = atan2(front.x, front.y)
		else:
			_place_spot(spots, families[entry[0]], node_name, entry[1])
	var pickups := _group("Pickups")
	for kind: Array in [["Bottles", BOTTLE, "Bottle", BOTTLES], ["Decoys", DECOY, "Decoy", DECOYS]]:
		var parent := Node3D.new()
		parent.name = kind[0]
		pickups.add_child(parent)
		parent.owner = _root
		for i in kind[3].size():
			_place_pickup(parent, kind[1], "%s%d" % [kind[2], i + 1], kind[3][i])


## A hiding spot with its back against the nearest wall, its front (+Z) toward
## the room.
func _place_spot(parent: Node3D, scene: PackedScene, node_name: String, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var spot: Node3D = scene.instantiate()
	spot.name = node_name
	parent.add_child(spot)
	spot.owner = _root
	spot.position = kit.world(at.x, at.z, at.y)
	var from := spot.position + Vector3.UP * SPOT_RAY_HEIGHT
	var best_distance := SPOT_WALL_SEARCH
	var wall := from
	var front := Vector3.BACK
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(
			from, from + direction * SPOT_WALL_SEARCH, MapKit.WALLS_LAYER
		)
		if spot.has_node("Body"):
			query.exclude = [spot.get_node("Body").get_rid()]
		var hit := space.intersect_ray(query)
		if hit and from.distance_to(hit.position) < best_distance:
			best_distance = from.distance_to(hit.position)
			wall = hit.position
			front = -direction
	if best_distance >= SPOT_WALL_SEARCH:
		push_warning("No wall near %s" % node_name)
		return
	var depth := 0.0
	if spot.has_node("Body"):
		var shape: BoxShape3D = spot.get_node("Body/CollisionShape3D").shape
		depth = shape.size.z
	var center := wall + front * (depth / 2.0 + 0.02)
	spot.position = Vector3(center.x, at.y, center.z)
	spot.rotation.y = atan2(front.x, front.z)


## A pickup on whatever lies below its point.
func _place_pickup(parent: Node3D, scene: PackedScene, node_name: String, at: Vector3) -> void:
	var space := _root.get_world_3d().direct_space_state
	var node: Node3D = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	var from := kit.world(at.x, at.z, at.y + 1.5)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5))
	node.position = hit.position if hit else kit.world(at.x, at.z, at.y)
	node.rotation.y = fposmod(at.x * 1.3 + at.z * 0.7, TAU)  # Not all lined up.


func _add_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	_root.add_child(props)
	props.owner = _root
	props.add_to_group("navigation_source", true)
	for i in LAMPPOSTS.size():
		_place(props, LAMPPOST, "Lamppost%d" % (i + 1), LAMPPOSTS[i][0], LAMPPOSTS[i][1])
	for i in BENCHES.size():
		var scene := BENCH_BROKEN if BENCHES[i][2] else BENCH_DIRTY
		_place(props, scene, "Bench%d" % (i + 1), BENCHES[i][0], BENCHES[i][1])
	for i in TREES.size():
		var turn := Vector2.from_angle(i * 1.7)
		_place(props, TREE_BARE, "Tree%d" % (i + 1), TREES[i], turn)
	_add_light(props, "TunnelLight", Vector2(155, 8), 3.2, Color(0.75, 0.85, 1.0), 1.2, 7.0)
	var cars := Node3D.new()
	cars.name = "CarAlarms"
	_add(cars)
	cars.add_to_group("navigation_source", true)
	for i in CAR_ALARMS.size():
		var scene := AMBULANCE_ALARM if i == AMBULANCE_CAR else CAR_ALARM
		_place(cars, scene, "Car%d" % (i + 1), CAR_ALARMS[i][0], CAR_ALARMS[i][1])
	_add_light(props, "TowerBeacon", Vector2(104, 100), TOWER_STOREYS * STOREY + 1.0, Color(1, 0.15, 0.1), 2.0, 6.0, false)
	_add_light(props, "SocialCentreLamp", Vector2(161.5, 58.5), 3.0, Color(1, 0.9, 0.7), 1.0, 5.0)
	_add_light(props, "LaundretteSign", Vector2(57.6, 137.5), 2.6, Color(0.7, 0.85, 1.0), 0.9, 5.0)
	_add_light(props, "CarParkSign", Vector2(127, 98.5), 3.0, Color(0.95, 0.95, 1.0), 0.8, 4.0)
	_add_light(props, "TransformerLight", Vector2(100.5, 158.5), 2.4, Color(0.35, 1, 0.55), 0.8, 5.0)


# --- Facade dressing (T-045) ------------------------------------------------


## Lays the facade modules on the blocks of flats and on the upper mass of the
## tower. The visited storeys of the tower keep their real windows.
func _add_facade_dressing() -> void:
	var dressing: FacadeDressing = FACADE_DRESSING.new()
	dressing.name = "FacadeDressing"
	dressing.models.assign(FACADE_MODELS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971  # Fixed: the cité looks the same after every generation.
	var wall := 0
	for facade_name: String in FACADES:
		var rect: Rect2 = FACADES[facade_name][0]
		var storeys: int = FACADES[facade_name][1]
		var porch: Variant = FACADES[facade_name][2]
		for side in _sides(rect):
			_dress_wall(dressing, rng, wall, side, storeys, porch)
			wall += 1
	for side in _sides(TOWER):
		_dress_wall(dressing, rng, wall, side, TOWER_STOREYS, null, true)
		wall += 1
	_add(dressing)


## Shop fronts, the laundrette and its machines (T-046). The models only
## dress the greybox walls, which keep the collisions.
func _add_gallery_dressing() -> void:
	var node := _group("GalleryDressing")
	var r := GALLERY
	var width := r.size.x / GALLERY_SHOPS
	var front := r.position.y + GALLERY_ARCADE_DEPTH - WALL / 2 - FACADE_OFFSET
	# The pharmacy, the tobacconist and the baker open since S-016 (T-240).
	var scenes := {0: SHOP_PHARMACIE, 1: LAUNDRETTE, 2: SHOP_TABAC, 3: SHOP_HALF, 4: SHOP_BOULANGERIE}
	for i: int in scenes:
		var east := r.position.x + (i + 1) * width
		_place_model(node, scenes[i], "Shop%d" % (i + 1), Vector2(east, front), Vector2.UP)
	var laundrette := r.position.x + width
	var back := r.end.y - GALLERY_BACK_CORRIDOR
	for i in 4:
		var mx := laundrette + 1.0 + i * 1.6
		_place_model(node, WASHERS, "Washers%d" % (i + 1), Vector2(mx + 0.61, back - 1.0), Vector2.UP)


## Window frames, the entrance canopy and its sign, the tables (T-046).
func _add_social_centre_dressing() -> void:
	var node := _group("SocialCentreDressing")
	var r := SOCIAL_CENTRE
	var n := 0
	for x: float in [146.0, 152.0, 168.0, 174.0]:  # North wall, seen from the north.
		n += 1
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(x, r.position.y - FACADE_OFFSET), Vector2.UP)
	for x: float in [144.0, 152.0, 168.0]:  # South wall.
		n += 1
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(x, r.end.y + FACADE_OFFSET), Vector2.DOWN)
	for y: float in [65.5, 73.5, 81.5]:  # East wall: narrower windows.
		n += 1
		var narrow := Vector3(1.5 / CENTRE_WINDOW_WIDTH, 1, 1)
		_place_model(node, CENTRE_WINDOW, "Window%d" % n, Vector2(r.end.x + FACADE_OFFSET, y), Vector2.RIGHT, narrow)
	_place_model(node, CENTRE_ENTRANCE, "Entrance", Vector2(162.6, r.position.y - FACADE_OFFSET), Vector2.UP)
	var tables: Array = [Vector2(149, 66), Vector2(155, 66), Vector2(149, 77), Vector2(155, 77)]
	for i in tables.size():
		_place_model(node, FOLDING_TABLE, "Table%d" % (i + 1), tables[i], Vector2.UP)
	for i in 3:  # Office desks, smaller.
		_place_model(node, FOLDING_TABLE, "Desk%d" % (i + 1), Vector2(172, 64 + 8 * i), Vector2.UP, Vector3(0.8, 1, 0.8))


## Every piece of furniture once (S-016, T-241): [model, plan point (x, height,
## y), facing, width scale], those of the flats on each visited storey, less
## those that would stand on a hiding spot, a pickup, a fuse slot or a point of
## the AIs.
func _furniture_pieces() -> Array:
	var pieces: Array = []
	for level in range(1, TOWER_VISITED_STOREYS):
		for piece: Array in FLAT_FURNITURE:
			var at: Vector2 = piece[1]
			pieces.append([piece[0], Vector3(at.x, level * STOREY, at.y), piece[2], 1.0])
	for piece: Array in FURNITURE + Hospital.FURNITURE:
		pieces.append([piece[0], piece[1], piece[2], piece[3] if piece.size() > 3 else 1.0])
	var keep_clear: Array = CLOSETS + BOTTLES + DECOYS + HIDING_SPOTS + PREY_ROUTE + PATROL_ROUTE
	for spot: Array in FAMILY_SPOTS + Hospital.SPOTS:
		keep_clear.append(spot[1])
	for entry: Array in _buildings().values():
		keep_clear.append_array(entry[4])
	var kept: Array = []
	for piece: Array in pieces:
		var at: Vector3 = piece[1]
		var area := _footprint(piece).grow(FURNITURE_CLEARANCE)
		var free := true
		for point: Vector3 in keep_clear:
			if absf(point.y - at.y) < 1.0 and area.has_point(Vector2(point.x, point.z)):
				free = false
				break
		if free:
			kept.append(piece)
	return kept


## The ground plan rectangle a piece of furniture covers, and its height in
## the third value of the model's box.
func _footprint(piece: Array) -> Rect2:
	var box := _model_box(FURNITURE_MODELS[piece[0]])
	var at: Vector3 = piece[1]
	var facing: Vector2 = piece[2]
	var side := Vector2(facing.y, -facing.x)  # The model's +X on the plan (_place_model).
	var lo := Vector2(INF, INF)
	var hi := -lo
	for x: float in [box.position.x * piece[3], box.end.x * piece[3]]:
		for z: float in [box.position.z, box.end.z]:
			var corner := Vector2(at.x, at.z) + side * x + facing * z
			lo = lo.min(corner)
			hi = hi.max(corner)
	return Rect2(lo, hi - lo)


## The box around a model's meshes, in its own space.
func _model_box(scene: PackedScene) -> AABB:
	var model: Node3D = scene.instantiate()
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := mesh.transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	model.free()
	return box


## The furniture stops bodies, sight and the navigation mesh like a low
## obstacle (S-016, Q7): a box around each model.
func _build_furniture() -> void:
	var s := kit.structure("Furniture")
	for piece: Array in _furniture_pieces():
		if FURNITURE_GHOSTS.has(piece[0]):
			continue
		var area := _footprint(piece)
		var at: Vector3 = piece[1]
		var height := _model_box(FURNITURE_MODELS[piece[0]]).end.y
		kit.box(s, area.position.x, area.position.y, area.end.x, area.end.y, at.y, at.y + height, null, MapKit.Kind.FLOOR)


func _add_furniture() -> void:
	var node: Node3D = FURNITURE_SCRIPT.new()
	node.name = "Furniture"
	_add(node)
	var counts := {}
	for piece: Array in _furniture_pieces():
		var key: String = piece[0]
		counts[key] = counts.get(key, 0) + 1
		var at: Vector3 = piece[1]
		var node_name := "%s%d" % [key.to_pascal_case(), counts[key]]
		var scale := Vector3(piece[3], 1, 1)
		_place_model(node, FURNITURE_MODELS[key], node_name, Vector2(at.x, at.z), piece[2], scale, at.y)
	# No navigation mesh on top of the low furniture either: the AIs would aim
	# for islands they cannot reach. Over the tall pieces, there is no room.
	var obstacles := _group("FurnitureObstacles")
	obstacles.add_to_group("navigation_source", true)
	for piece: Array in _furniture_pieces():
		if FURNITURE_GHOSTS.has(piece[0]):
			continue
		var height := _model_box(FURNITURE_MODELS[piece[0]]).end.y
		if height > FURNITURE_TALL:
			continue
		var area := _footprint(piece)
		var at: Vector3 = piece[1]
		var obstacle := NavigationObstacle3D.new()
		obstacle.position = kit.world(area.position.x, area.position.y, at.y - 0.1)
		obstacle.vertices = PackedVector3Array([
			Vector3.ZERO, Vector3(area.size.x, 0, 0), Vector3(area.size.x, 0, area.size.y), Vector3(0, 0, area.size.y),
		])
		obstacle.height = height + 0.6
		obstacle.affect_navigation_mesh = true
		obstacle.avoidance_enabled = false
		obstacles.add_child(obstacle)
		obstacle.owner = _root


## Wrecks, pillars, dead neons, the "P" sign and the garage doors (T-047).
func _add_car_park_dressing() -> void:
	var node := _group("CarParkDressing")
	var r := CAR_PARK
	var floor_h := -CAR_PARK_DEPTH
	var ceiling := -GROUND_THICKNESS
	for i in CAR_PARK_WRECKS.size():
		var turn := Vector2.UP if i % 2 == 0 else Vector2.DOWN
		_place_model(node, CAR_WRECK, "Wreck%d" % (i + 1), CAR_PARK_WRECKS[i], turn, Vector3.ONE, floor_h)
	var n := 0
	var px := r.position.x + CAR_PARK_PILLAR_STEP
	while px < r.end.x - 1.0:
		for py: float in [r.position.y + r.size.y / 3.0, r.position.y + 2.0 * r.size.y / 3.0]:
			n += 1
			_place_model(node, CAR_PARK_PILLAR, "Pillar%d" % n, Vector2(px, py), Vector2.UP, Vector3.ONE, floor_h)
		var neon := Vector2(px - CAR_PARK_PILLAR_STEP / 2.0, r.get_center().y)
		_place_model(node, NEON_FIXTURE, "Neon%d" % n, neon, Vector2.UP, Vector3.ONE, ceiling)
		px += CAR_PARK_PILLAR_STEP
	_place_model(node, CAR_PARK_SIGN, "SignP", Vector2(126.7, 99.5), Vector2.LEFT)
	# Garage doors on the east wall of the boxes, seen from the east.
	var g := GARAGES
	var width := g.size.y / GARAGE_COUNT
	for i in GARAGE_COUNT:
		var south := g.position.y + (i + 1) * width - 0.5
		var scene := GARAGE_OPEN if GARAGES_OPEN.has(i) else GARAGE_CLOSED
		_place_model(node, scene, "Garage%d" % (i + 1), Vector2(g.end.x + FACADE_OFFSET, south), Vector2.RIGHT)


## Transformer, playground and city stadium (T-048).
func _add_outdoor_dressing() -> void:
	var node := _group("OutdoorDressing")
	_place_model(node, TRANSFORMER, "Transformer", Vector2(100.5, 153.5), Vector2.UP)
	_place_model(node, SWING, "Swing", Vector2(61, 80.5), Vector2.UP)
	_place_model(node, CLIMBING_FRAME, "ClimbingFrame", Vector2(54.5, 74.5), Vector2.UP)
	_place_model(node, STADIUM_GOAL, "GoalWest", Vector2(149.5, 190), Vector2.RIGHT)
	_place_model(node, STADIUM_GOAL, "GoalEast", Vector2(176.5, 190), Vector2.LEFT)
	# Boards of the city stadium, facing out, around the openings (west, north).
	var runs := [
		[Vector2(160, 180), Vector2(148, 180), Vector2.UP],
		[Vector2(178, 180), Vector2(166, 180), Vector2.UP],
		[Vector2(148, 200), Vector2(178, 200), Vector2.DOWN],
		[Vector2(148, 180), Vector2(148, 188), Vector2.LEFT],
		[Vector2(148, 192), Vector2(148, 200), Vector2.LEFT],
		[Vector2(178, 200), Vector2(178, 180), Vector2.RIGHT],
	]
	# One MultiMesh per run: 45 separate boards would cost 90 draw calls.
	var boards: FacadeDressing = FACADE_DRESSING.new()
	boards.name = "StadiumBoards"
	boards.models.assign([STADIUM_BOARD])
	for r in runs.size():
		var from: Vector2 = runs[r][0]
		var to: Vector2 = runs[r][1]
		var normal: Vector2 = runs[r][2]
		var along := (to - from).normalized()
		var z_axis := Vector3(normal.x, 0, normal.y)
		var basis := Basis(Vector3.UP.cross(z_axis), Vector3.UP, z_axis)
		for i in roundi(from.distance_to(to) / STADIUM_BOARD_WIDTH):
			var at := from + along * (i * STADIUM_BOARD_WIDTH)
			boards.panels.append(Transform3D(basis, kit.world(at.x, at.y, 0.0)))
			boards.variants.append(0)
			boards.walls.append(r)
	node.add_child(boards)
	boards.owner = _root


## Wind everywhere, the motorway to the east, a train on the embankment now
## and then, the swing creaking (T-050). Plain players: none of them goes
## through NoiseBus, so they betray nobody.
func _add_ambience() -> void:
	var node := _group("Ambience")
	var wind := AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = WIND_SOUND
	wind.volume_db = -12.0
	wind.autoplay = true
	node.add_child(wind)
	wind.owner = _root
	for i in MOTORWAY_SOURCES.size():
		var road := _sound(node, "Motorway%d" % (i + 1), MOTORWAY_SOUND, Vector2(216, MOTORWAY_SOURCES[i]), 1.0)
		road.unit_size = 25.0
		road.max_distance = 150.0
		road.volume_db = -4.0
	var train: AudioStreamPlayer3D = AMBIENT_TRAIN.new()
	train.name = "Train"
	train.stream = TRAIN_SOUND
	train.unit_size = 40.0
	train.max_distance = 220.0
	train.track_start = kit.world(-40, 1, 7)
	train.track_end = kit.world(260, 1, 7)
	node.add_child(train)
	train.owner = _root
	var swing := _sound(node, "SwingCreak", SWING_SOUND, Vector2(61, 80.5), 2.0)
	swing.unit_size = 3.0
	swing.max_distance = 18.0


func _sound(parent: Node3D, node_name: String, stream: AudioStream, at: Vector2, h: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = stream
	player.autoplay = true
	player.position = kit.world(at.x, at.y, h)
	parent.add_child(player)
	player.owner = _root
	return player


func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_add(node)
	return node


## Instances a model at a plan point, its front (+Z) toward normal, its +X
## running along the wall as for the facade modules.
func _place_model(parent: Node3D, scene: PackedScene, node_name: String, at: Vector2, normal: Vector2, scale := Vector3.ONE, h := 0.0) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.name = node_name
	var z_axis := Vector3(normal.x, 0, normal.y)
	var x_axis := Vector3.UP.cross(z_axis)
	model.transform = Transform3D(Basis(x_axis * scale.x, Vector3.UP * scale.y, z_axis * scale.z), kit.world(at.x, at.y, h))
	parent.add_child(model)
	model.owner = _root
	return model


## The four outer walls of a rectangle, each as [start, end, outward normal] in
## plan coordinates, walked so that the module's +X runs from start to end.
func _sides(r: Rect2) -> Array:
	var nw := r.position
	var ne := Vector2(r.end.x, r.position.y)
	var se := r.end
	var sw := Vector2(r.position.x, r.end.y)
	return [
		[ne, nw, Vector2.UP],  # North: faces -y, walked east to west.
		[nw, sw, Vector2.LEFT],
		[sw, se, Vector2.DOWN],
		[se, ne, Vector2.RIGHT],
	]


func _dress_wall(
	dressing: FacadeDressing, rng: RandomNumberGenerator, wall: int, side: Array, storeys: int, porch: Variant, tower := false
) -> void:
	var start: Vector2 = side[0]
	var end: Vector2 = side[1]
	var normal: Vector2 = side[2]
	var length := start.distance_to(end)
	var count := maxi(1, roundi(length / MODULE_WIDTH))
	var width := length / count
	var along := (end - start).normalized()
	var x_axis := Vector3(along.x, 0, along.y) * (width / MODULE_WIDTH)
	var z_axis := Vector3(normal.x, 0, normal.y)
	var basis := Basis(x_axis, Vector3.UP, z_axis)
	var door_every := maxi(1, roundi(DOOR_SPACING / width))
	for column in count:
		var at := start + along * (column * width) + normal * FACADE_OFFSET
		var mid := start + along * ((column + 0.5) * width)
		var under_porch: bool = porch != null and mid.x > porch.x and mid.x < porch.y and absf(normal.y) > 0.5
		var balconies := rng.randf() < BALCONY_SHARE
		# The hall entrances of the tower stay open (north and south, ground floor).
		var entrance: bool = tower and absf(normal.y) > 0.5 and (mid.x > TOWER_NORTH_DOORS.x - 3.0 and mid.x < TOWER_NORTH_DOORS.y + 1.0 if normal.y < 0 else mid.x > TOWER_SOUTH_DOORS.x - 2.0 and mid.x < TOWER_SOUTH_DOORS.y + 2.0)
		var fire_escape: bool = tower and normal.x > 0.5 and absf(mid.y - (FIRE_ESCAPE_DOOR.x + FIRE_ESCAPE_DOOR.y) / 2.0) < width
		for storey in storeys:
			if under_porch and storey * STOREY < PORCH_HEIGHT:
				continue
			if entrance and storey == 0:
				continue
			# The doors onto the fire escape stay clear (S-016).
			if fire_escape and storey > 0 and storey < TOWER_VISITED_STOREYS:
				continue
			var module: int
			if tower and storey > 0 and storey < TOWER_VISITED_STOREYS:
				module = Module.OPEN
			elif storey == 0:
				var door := not tower and column % door_every == door_every / 2 and absf(normal.y) > 0.5
				module = Module.DOOR if door else (Module.WALLED if rng.randf() < WALLED_SHARE else Module.PLAIN)
			elif balconies:
				module = Module.BALCONY
			else:
				module = Module.LIT if rng.randf() < LIT_SHARE else Module.PLAIN
			var origin := kit.world(at.x, at.y) + Vector3.UP * (storey * STOREY)
			dressing.panels.append(Transform3D(basis, origin))
			dressing.variants.append(module)
			dressing.walls.append(wall)


## Instances a prop at a plan point, its local -Z (front) turned toward facing.
func _place(parent: Node3D, scene: PackedScene, node_name: String, at: Vector2, facing: Vector2) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	node.position = kit.world(at.x, at.y)
	node.rotation.y = atan2(-facing.x, -facing.y)
	return node


func _add_light(
	parent: Node3D, node_name: String, at: Vector2, height: float, color: Color,
	energy: float, light_range: float, fade := true
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_cull_mask = ~MapKit.BAKED_LAYER & 0xFFFFF
	light.distance_fade_enabled = fade
	light.distance_fade_begin = LIGHT_FADE_BEGIN
	light.distance_fade_length = LIGHT_FADE_LENGTH
	light.position = kit.world(at.x, at.y, height)
	parent.add_child(light)
	light.owner = _root
	return light


## Bakes the street lights and the landmark lights into the ground and the
## walls (T-049, plan B: no GPU for LightmapGI). Their real lights now only
## light the models, and fade out past LIGHT_FADE_BEGIN.
func _bake_light() -> void:
	var lights: Array[OmniLight3D] = []
	lights.assign(_root.get_node("Props").find_children("*", "OmniLight3D", true, false))
	var started := Time.get_ticks_msec()
	var space := _root.get_world_3d().direct_space_state
	var count := kit.bake_light(lights, space, MapKit.WORLD_LAYER | MapKit.WALLS_LAYER)
	print(
		"Baked %d lights in %d vertices in %d ms"
		% [lights.size(), count, Time.get_ticks_msec() - started]
	)


func _add_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	mesh.cell_size = 0.125
	# Lower than the monster (2.2 m): with cells 0.25 m high, a 2.4 m door
	# leaves less than 2.25 m of clearance on the voxel grid.
	mesh.agent_height = 2.0
	mesh.agent_radius = 0.375
	# Only inside the fences: no useless islands on the motorway or the wasteland.
	# The bottom sits just under a multiple of the cell height (0.25 m), so the
	# mesh lies about 0.26 m above floors at whole storeys: closer than the AI
	# agents' path_desired_distance (0.5 m), or they would never pass a path point.
	var lo := kit.world(FENCED.position.x, FENCED.position.y, NAV_BOTTOM)
	var hi := kit.world(FENCED.end.x, FENCED.end.y, 20)
	mesh.filter_baking_aabb = AABB(lo, hi - lo)
	region.navigation_mesh = mesh
	_root.add_child(region)
	region.owner = _root


func _add_gameplay() -> void:
	_root.set_script(MAP_SCRIPT)
	_add_loop()
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.fog_enabled = true
	env.environment = environment
	env.set_script(NIGHT_SCRIPT)
	_add(env)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.transform = Transform3D(Basis.from_euler(Vector3(-PI / 4, PI / 6, 0)), Vector3(0, 30, 0))
	_add(moon)
	env.set("moon", moon)
	var retro_world := Node.new()
	retro_world.name = "RetroWorld"
	retro_world.set_script(RETRO_WORLD_SCRIPT)
	_add(retro_world)
	_add(_named(RETRO_POST.instantiate(), "RetroPost"))
	var spawns := _markers("PlayerSpawns", PLAYER_SPAWNS)
	# Each hunted starts facing the tower, the landmark of the cité.
	var tower_center := kit.world(TOWER.get_center().x, TOWER.get_center().y)
	for marker: Node3D in spawns.get_children():
		var to := tower_center - marker.position
		marker.rotation.y = atan2(-to.x, -to.z)
	var monster_spawn := _markers("MonsterSpawn", [MONSTER_SPAWN])
	var patrol := _markers("PatrolRoute", PATROL_ROUTE)
	_markers("PreyRoute", PREY_ROUTE)
	_markers("HidingSpots", HIDING_SPOTS)
	_markers("GuardPoints", GUARD_POINTS)
	var monster: Node3D = _named(MONSTER.instantiate(), "Monster")
	monster.position = monster_spawn.get_child(0).position
	monster.set("patrol_route", patrol)
	monster.set("start_index", 0)
	_add(monster)
	_add(_named(NOISE_DEBUG.instantiate(), "NoiseDebug"))
	var player: Node3D = _named(PLAYER.instantiate(), "Player")
	player.transform = spawns.get_child(0).transform
	_add(player)
	var overlay := _named(OVERLAY.instantiate(), "DebugOverlay")
	overlay.set("player", player)
	overlay.set("monster", monster)
	_add(overlay)
	var gauge := _named(GAUGE.instantiate(), "NoiseGauge")
	gauge.set("player", player)
	_add(gauge)
	var prompt := _named(INTERACT_PROMPT.instantiate(), "InteractPrompt")
	prompt.set("player", player)
	_add(prompt)
	_add(_named(CAUGHT.instantiate(), "CaughtScreen"))


## Patrol of the AI monster, as plan points (x, height, y): every street and
## the inside of each scannable building, from its corner (T-041).
const PATROL_ROUTE := [
	Vector3(190, 0, 190), Vector3(200, 0, 125), Vector3(160, -3, 106), Vector3(150, 0, 122),
	Vector3(161.5, 0, 72), Vector3(155, 0, 45), Vector3(104, 0, 92), Vector3(108, 12, 100),
	Vector3(66, 0, 137), Vector3(84, 0, 148), Vector3(40, 0, 150), Vector3(14, 0, 158.5),
	Vector3(40, 0, 120), Vector3(61, 0, 81), Vector3(40, 0, 52), Vector3(100, 0, 52),
	Vector3(120, 0, 140), Vector3(163, 0, 190),
]
## Where the AI monster walks to and fro once the exit is open (S-007, Q4):
## the south mouth of the tunnel and both sides of it.
const GUARD_POINTS := [Vector3(155, 0, 14), Vector3(146, 0, 20), Vector3(164, 0, 20)]
## Wander points of the AI prey (monster role), outside and inside.
const PREY_ROUTE := [
	Vector3(45, 0, 44), Vector3(95, 0, 52), Vector3(155, 0, 40), Vector3(124, 0, 96),
	Vector3(96, 6, 100), Vector3(105, 0, 140), Vector3(61, 0, 80), Vector3(40, 0, 150),
	Vector3(56, 0, 143), Vector3(72, 0, 112), Vector3(150, 0, 72), Vector3(160, -3, 110),
]
## Hiding spots of the AI prey: in the lee of a block, or inside a building.
const HIDING_SPOTS := [
	Vector3(29, 0, 95), Vector3(88, 0, 36), Vector3(183, 0, 80), Vector3(139, 0, 180),
	Vector3(98, 0, 159), Vector3(70, 0, 208), Vector3(95, 9, 109), Vector3(160, -3, 111),
	Vector3(13, 0, 176), Vector3(54.5, 0, 145.5),
]


func _markers(node_name: String, points: Array) -> Node3D:
	var parent := Node3D.new()
	parent.name = node_name
	_add(parent)
	for i in points.size():
		var marker := Marker3D.new()
		marker.name = "Point%d" % (i + 1)
		var at: Variant = points[i]
		if at is Vector3:
			marker.position = kit.world(at.x, at.z, at.y)
		else:
			marker.position = kit.world(at.x, at.y)
		parent.add_child(marker)
		marker.owner = _root
	return parent


func _add(node: Node) -> void:
	_root.add_child(node)
	node.owner = _root


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


## Plain colored materials of the greybox, made once and shared.
func _material(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	match key:
		"grille":
			material.albedo_color = Color(0.16, 0.17, 0.18)
		"fence":
			material.albedo_color = Color(0.32, 0.33, 0.3)
		"metal":
			material.albedo_color = Color(0.38, 0.4, 0.42)
			material.roughness = 0.6
		"transformer":
			material.albedo_color = Color(0.2, 0.36, 0.26)
		"garage_door":
			material.albedo_color = Color(0.3, 0.32, 0.36)
			material.roughness = 0.6
		"beacon":
			_glow(material, Color(1, 0.12, 0.08))
		"sign_warm":
			_glow(material, Color(0.95, 0.88, 0.7))
		"sign_cold":
			_glow(material, Color(0.7, 0.85, 1.0))
		"sign_white":
			_glow(material, Color(0.92, 0.94, 1.0))
	_materials[key] = material
	return material


## A sign or a beacon: lit by itself, never orange (constitution 2.3).
func _glow(material: StandardMaterial3D, color: Color) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
