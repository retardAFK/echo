extends Node
## Layout of the cité des Tilleuls (spec S-006, S-022 T-432): every fixed
## position, size and scene the generator uses, in plan coordinates (x east,
## y south, meters; see map_kit.gd). Part of the generator chain:
## tilleuls_layout.gd → tilleuls_base.gd → tilleuls_tower.gd →
## tilleuls_places.gd → build_tilleuls.gd (run that one). Split in files under
## 1 000 lines; each file extends the previous one.

## Modules of the blocks of flats facades (FACADE_MODELS, same order).
## OPEN has a real hole: it dresses the visited storeys of the tower, in front
## of their window openings.
enum Module { PLAIN, LIT, BALCONY, WALLED, DOOR, OPEN }

const MapKit := preload("res://tools/godot/map_kit.gd")

const InteriorLining := preload("res://tools/godot/interior_lining.gd")

const Hospital := preload("res://tools/godot/hospital.gd")

const FloorBuilder := preload("res://tools/godot/floor_builder.gd")

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
## The transformer's keypad: a box on its wall, not a PC on a desk (S-020, T-316).
const TERMINAL_KEYPAD := preload("res://game/entities/network/terminal_keypad.tscn")

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
	Vector2(45.8, 47.0),
	Vector2(55.4, 57.8),
	Vector2(63.8, 67.8),
	Vector2(72.2, 75.2),
	Vector2(80.6, 81.8),
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
	Vector2(45, 44),
	Vector2(95, 44),
	Vector2(32, 150),
	Vector2(72, 112),
	Vector2(127, 96),
	Vector2(170, 44),  # Clear of the tower's fire escape (S-016).
]

const MONSTER_SPAWN := Vector2(190, 190)

## The lights fade out from this distance to the camera, over LIGHT_FADE_LENGTH
## (T-049): farther, only their baked light shows. Same as lamppost.tscn.
const LIGHT_FADE_BEGIN := 20.0

const LIGHT_FADE_LENGTH := 5.0

## Lampposts: plan position and the direction the arm points to.
const LAMPPOSTS := [
	[Vector2(158, 20), Vector2.LEFT],
	[Vector2(158, 46), Vector2.LEFT],
	[Vector2(130, 47), Vector2.DOWN],
	[Vector2(80, 47), Vector2.DOWN],
	[Vector2(50, 47), Vector2.DOWN],
	[Vector2(37, 80), Vector2.RIGHT],
	[Vector2(37, 112), Vector2.RIGHT],
	[Vector2(37, 145), Vector2.RIGHT],
	[Vector2(37, 178), Vector2.RIGHT],
	[Vector2(72, 188), Vector2.UP],
	[Vector2(102, 160), Vector2.RIGHT],
	[Vector2(108, 135), Vector2.LEFT],
	[Vector2(108, 75), Vector2.LEFT],
	[Vector2(135, 117), Vector2.DOWN],
	[Vector2(168, 123), Vector2.UP],
	[Vector2(197, 150), Vector2.RIGHT],
	[Vector2(203, 180), Vector2.LEFT],
	[Vector2(61, 84.5), Vector2.UP],
	[Vector2(163, 178), Vector2.DOWN],
]

## The 6 cars with an alarm (Q7), parked along the streets: plan position and
## the direction of their length.
const CAR_ALARMS := [
	[Vector2(36, 45), Vector2.RIGHT],
	[Vector2(120, 45), Vector2.RIGHT],
	[Vector2(205, 140), Vector2.UP],
	[Vector2(85, 170), Vector2.RIGHT],
	[Vector2(35, 106), Vector2.UP],
	[Vector2(186, 206), Vector2.RIGHT],
]

## Benches and trees: plan position and the direction they face.
const BENCHES := [
	[Vector2(52, 90), Vector2.UP, false],
	[Vector2(70, 90), Vector2.UP, true],
	[Vector2(110, 125), Vector2.UP, false],
	[Vector2(150, 178), Vector2.UP, true],
	[Vector2(44, 160), Vector2.LEFT, false],
]

const TREES := [
	Vector2(48, 68),
	Vector2(74, 72),
	Vector2(49, 95),
	Vector2(36, 53),
	Vector2(82, 160),
	Vector2(120, 140),
	Vector2(176, 128),
	Vector2(140, 40),
	Vector2(112, 60),
	Vector2(64, 120),
	Vector2(20, 186),
	Vector2(185, 170),
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
	Vector3(93, 0, 109),
	Vector3(93.5, 3, 90),
	Vector3(103, 9, 109.5),  # Tower: bin room, flats.
	Vector3(164.2, 0, 61.5),
	Vector3(148, 0, 61),
	Vector3(176.8, 0, 82.5),  # Social centre.
	Vector3(54.2, 0, 141),
	Vector3(81.5, 0, 146.5),
	Vector3(45.8, 0, 141),  # Gallery.
	Vector3(141, -3, 112),
	Vector3(179, -3, 106),
	Vector3(152, -3, 95.8),  # Car park.
]

## The other families (S-016, Q6): low (under a bed), makeshift (behind a
## curtain), metal (the stuck lift). A third value places the spot there,
## its front toward that plan direction, instead of against the nearest wall.
const FAMILY_SPOTS := [
	["Metal", Vector3(100, 0, 91.6)],  # Tower: the lift cabin.
	["Low", Vector3(113, 3, 90)],
	["Low", Vector3(101, 6, 110.5)],
	["Low", Vector3(113, 9, 104.5)],
	["Makeshift", Vector3(92.6, 3, 103)],
	["Makeshift", Vector3(115.6, 6, 104)],
	["Makeshift", Vector3(110, 12, 88.6)],
	["Low", Vector3(101, 12, 110.5)],
	["Makeshift", Vector3(92.6, 9, 103)],
	["Low", Vector3(143, 0, 73.5), Vector2.RIGHT],  # Social centre: under the stage,
	["Low", Vector3(143, 0, 67), Vector2.RIGHT],
	["Makeshift", Vector3(140.85, 0, 65)],
	["Makeshift", Vector3(158.2, 0, 63)],  # the wings, the chairs,
	["Metal", Vector3(153.5, 0, 83)],  # the kitchen's cold cabinet.
	["Low", Vector3(48.5, 0, 144.5)],
	["Metal", Vector3(54, 0, 145.5)],  # Gallery: pharmacy, dryer,
	["Makeshift", Vector3(64.5, 0, 146.4)],
	["Metal", Vector3(85.5, 0, 145.3)],  # boxes, oven.
	["Metal", Vector3(154, -3, 101.05), Vector2.DOWN],  # Car park: a wreck's boot,
	["Low", Vector3(160, -3, 113.5), Vector2.LEFT],  # under a wreck,
	["Metal", Vector3(166, -3, 103.55), Vector2.DOWN],  # another boot,
	["Makeshift", Vector3(129.2, -3, 94.6)],  # boxes in the open cellar cage.
]

## Furniture of every visited storey of the tower (S-016, Q7): model, plan
## point, its front toward that plan direction. North-west, north-east,
## south-west and south-east flats.
const FLAT_FURNITURE := [
	["bed", Vector2(93.3, 95.5), Vector2.RIGHT],
	["sofa", Vector2(98.0, 88.55), Vector2.DOWN],
	["boxes", Vector2(100.0, 95.5), Vector2.LEFT],
	["lift_doors", Vector2(100.0, 91.0), Vector2.DOWN],
	["bed", Vector2(114.8, 95.5), Vector2.LEFT],
	["kitchen_table", Vector2(108.3, 92.5), Vector2.DOWN],
	["fridge", Vector2(106.1, 88.45), Vector2.DOWN],
	["sofa", Vector2(95.5, 106.45), Vector2.UP],
	["boxes", Vector2(102.6, 102.9), Vector2.LEFT],
	["bed", Vector2(100.6, 110.85), Vector2.UP],
	["sofa", Vector2(115.45, 104.6), Vector2.LEFT],
	["kitchen_table", Vector2(109.6, 104.2), Vector2.DOWN],
	["bed", Vector2(106.0, 110.85), Vector2.UP],
	["fridge", Vector2(115.58, 102.0), Vector2.LEFT],
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
	["shelves", Vector3(168, 0, 67.6), Vector2.UP],
	["boxes", Vector3(166, 0, 75.2), Vector2.UP],
	# Gallery: counters of the pharmacy, the grocer and the baker, the
	# tobacconist's shelves.
	["counter", Vector3(48.5, 0, 143.4), Vector2.UP, 5.0 / 2.1],
	["shelves", Vector3(62.9, 0, 143), Vector2.RIGHT],
	["shelves", Vector3(62.9, 0, 145), Vector2.RIGHT],
	["shelves", Vector3(66.4, 0, 143), Vector2.LEFT],
	["shelves", Vector3(66.4, 0, 145), Vector2.LEFT],
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
	Vector3(30, 0, 35),
	Vector3(33.2, 0, 128),
	Vector3(180, 0, 35),
	Vector3(184, 0, 92),
	Vector3(185, 0, 144),
	Vector3(90, 0, 191),
]

## 20 bottles, all there every game (Q1): low walls, benches, halls, car park.
const BOTTLES := [
	Vector3(55, 0, 70.15),
	Vector3(68, 0, 91.85),
	Vector3(50.15, 0, 85),  # Playground kerb.
	Vector3(53.5, 0, 90.5),
	Vector3(111.5, 0, 125.8),
	Vector3(151.5, 0, 178.6),  # Benches.
	Vector3(44.2, 0, 161.6),
	Vector3(148, 0, 184),  # Bench, city stadium board.
	Vector3(113, 0, 99),
	Vector3(100.5, 0, 110.5),
	Vector3(97, 6, 100),  # Tower.
	Vector3(161.5, 0, 82),
	Vector3(50, 0, 137.5),
	Vector3(82, 0, 137.5),  # Halls, arcade.
	Vector3(60.5, 0, 141),
	Vector3(150, -3, 115.8),
	Vector3(165, -3, 96),  # Laundrette, car park.
	Vector3(178.5, -3, 110),
	Vector3(125, 0, 104.5),
	Vector3(95, 0, 158),  # Ramp, transformer.
]

## 10 places for an alarm clock, 4 drawn each game by GameLoop (Q3): the open
## garages, the car park, the offices of the social centre, the back corridor
## of the gallery.
const DECOYS := [
	Vector3(10.2, 0, 157.2),
	Vector3(10.2, 0, 174.7),
	Vector3(146, -3, 96.5),
	Vector3(168, -3, 116.2),
	Vector3(156.8, -3, 102.33),
	Vector3(176, -3, 101.3),
	Vector3(173, 0, 61),
	Vector3(165, 0, 83),
	Vector3(50, 0, 148),
	Vector3(79, 0, 148),
]

## Patrol of the AI monster, as plan points (x, height, y): every street and
## the inside of each scannable building, from its corner (T-041).
const PATROL_ROUTE := [
	Vector3(190, 0, 190),
	Vector3(200, 0, 125),
	Vector3(160, -3, 106),
	Vector3(150, 0, 122),
	Vector3(161.5, 0, 72),
	Vector3(155, 0, 45),
	Vector3(104, 0, 92),
	Vector3(108, 12, 100),
	Vector3(66, 0, 137),
	Vector3(84, 0, 148),
	Vector3(40, 0, 150),
	Vector3(14, 0, 158.5),
	Vector3(40, 0, 120),
	Vector3(61, 0, 81),
	Vector3(40, 0, 52),
	Vector3(100, 0, 52),
	Vector3(120, 0, 140),
	Vector3(163, 0, 190),
]

## Where the AI monster walks to and fro once the exit is open (S-007, Q4):
## the south mouth of the tunnel and both sides of it.
const GUARD_POINTS := [Vector3(155, 0, 14), Vector3(146, 0, 20), Vector3(164, 0, 20)]

## Wander points of the AI prey (monster role), outside and inside.
const PREY_ROUTE := [
	Vector3(45, 0, 44),
	Vector3(95, 0, 52),
	Vector3(155, 0, 40),
	Vector3(124, 0, 96),
	Vector3(96, 6, 100),
	Vector3(105, 0, 140),
	Vector3(61, 0, 80),
	Vector3(40, 0, 150),
	Vector3(56, 0, 143),
	Vector3(72, 0, 112),
	Vector3(150, 0, 72),
	Vector3(160, -3, 110),
]

## Hiding spots of the AI prey: in the lee of a block, or inside a building.
const HIDING_SPOTS := [
	Vector3(29, 0, 95),
	Vector3(88, 0, 36),
	Vector3(183, 0, 80),
	Vector3(139, 0, 180),
	Vector3(98, 0, 159),
	Vector3(70, 0, 208),
	Vector3(95, 9, 109),
	Vector3(160, -3, 111),
	Vector3(13, 0, 176),
	Vector3(54.5, 0, 145.5),
]
