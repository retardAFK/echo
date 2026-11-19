class_name NetSettings
extends Resource
## Values of the online game (spec S-010, plan, T-094).

## Where the server is: "ws://127.0.0.1" on this machine (ports used directly),
## "wss://<domain>" online (Caddy routes /lobby and /s1../s8 to the ports).
## The CI writes the online address into the web build.
@export var server_address: String = "ws://127.0.0.1"
## Whether the start menu offers "Jouer en ligne". Off until the online game
## is playable and the server is online (T-097, T-108).
@export var show_online: bool = false
## Address the lobby and the rooms listen on. Caddy reaches them on the same machine.
@export var bind_address: String = "127.0.0.1"
## Port of the lobby, which hands out game codes.
@export_range(1024, 65535) var lobby_port: int = 8910
## Port of the first room; room n (1 to max_rooms) listens on first_room_port + n - 1.
@export_range(1024, 65535) var first_room_port: int = 9001
## Games running at the same time at most (one process each).
@export_range(1, 32) var max_rooms: int = 8
## Players in a room: 1 monster and 3 hunted (S-010, Q1).
@export_range(1, 8) var room_size: int = 4
## A room nobody is in stops after this long, freeing its code.
@export_range(5.0, 600.0, 1.0, "suffix:s") var room_idle_timeout: float = 60.0
## Commands sent by a client per second (S-010, Q5).
@export_range(5, 60) var commands_rate: int = 30
## Frames of held commands in each packet a client sends (S-020, T-321): the
## new ones and the last ones again, so a lost packet costs nothing.
@export_range(1, 16) var frames_per_packet: int = 4
## Room side: frames of a player queued before playing them, again after the
## queue ran dry (T-321), to ride out the bursts of the WebSocket.
@export_range(0, 10) var command_lead: int = 3
## Room side: beyond this many frames queued, the oldest are dropped.
@export_range(1, 60) var command_max_backlog: int = 8
## Snapshots sent by the room to each client per second (S-010, Q5).
@export_range(5, 60) var snapshot_rate: int = 20
## Other players are shown this far in the past, between two snapshots (Q8);
## 0.2 s since S-020, T-319, to ride out bursts of snapshots.
@export_range(0.0, 0.5, 0.01, "suffix:s") var interpolation_delay: float = 0.2
## Client side: the room's clock (S-020, T-320) takes the quickest trip of
## the snapshots over this window, and follows it at most this fast (s per s).
@export_range(0.5, 10.0, 0.1, "suffix:s") var clock_window: float = 2.0
@export_range(0.0, 0.2, 0.005) var clock_max_drift: float = 0.02
## When a snapshot is late, others keep moving at most this long, then stop.
@export_range(0.0, 0.5, 0.01, "suffix:s") var max_extrapolation: float = 0.15
## Gap between the predicted and the room's position corrected smoothly...
## (1 m and 0.4 s since S-020, T-319: a network hiccup at a sprint, about
## 0.55 m, no longer makes the player snap back and forth)
@export_range(0.0, 2.0, 0.05, "suffix:m") var correction_threshold: float = 1.0
## ...over this time, and above this gap the player jumps to the room's position.
@export_range(0.01, 1.0, 0.01, "suffix:s") var correction_time: float = 0.4
@export_range(0.5, 10.0, 0.1, "suffix:m") var snap_threshold: float = 2.0
## A gap under correction_threshold but above this is settled slowly, over
## settle_time, so that a player standing still ends where the room has it
## (S-020, T-319): kept for good, it made the room's player aim elsewhere.
@export_range(0.0, 0.5, 0.01, "suffix:m") var settle_threshold: float = 0.05
@export_range(0.1, 5.0, 0.1, "suffix:s") var settle_time: float = 1.0
## Players further than this are never sent to a hunted (night sight, plan S-010).
@export_range(5.0, 200.0, 1.0, "suffix:m") var sight_range: float = 40.0
## Half-angle of the view cone used to filter what a client receives; wider
## than the camera, so nobody pops in when the head turns.
@export_range(30.0, 180.0, 1.0, "suffix:°") var sight_half_angle: float = 110.0
## Added delay on every message, both ways, to test a bad connection (tests only).
@export_range(0, 500, 1, "suffix:ms") var debug_latency_ms: int = 0
## Random extra delay up to this, on top of debug_latency_ms, on what a client
## sends and receives (tests only, S-020, T-319). Messages keep their order,
## as on a WebSocket: a late one holds back those behind it, which then
## arrive in a burst.
@export_range(0, 500, 1, "suffix:ms") var debug_jitter_ms: int = 0
## Time between two pings sent by a client.
@export_range(0.1, 10.0, 0.1, "suffix:s") var ping_interval: float = 1.0
## How long a client waits for the lobby to answer.
@export_range(1.0, 30.0, 0.5, "suffix:s") var lobby_timeout: float = 5.0
## How long a client keeps trying to reach a room that is still starting.
@export_range(0.5, 30.0, 0.5, "suffix:s") var room_connect_timeout: float = 5.0
## Time between two tries to reach a room that is still starting.
@export_range(0.05, 5.0, 0.05, "suffix:s") var room_connect_retry: float = 0.25
## After the end of a game, how long the room waits before going back to its
## waiting room (T-099).
@export_range(0.5, 30.0, 0.5, "suffix:s") var end_return_delay: float = 3.0
## Seconds a player who left a game keeps its place before an AI takes it
## where it was (T-102); back before the end, it takes it again.
@export_range(0.0, 120.0, 0.5, "suffix:s") var seat_keep_time: float = 10.0
