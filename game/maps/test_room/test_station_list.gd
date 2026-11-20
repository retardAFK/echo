class_name TestStationList
extends Resource
## The stations of the test room (spec S-023, Q9, T-356), in
## game/maps/test_room/stations.tres. Add or remove a station there: one
## TestStation sub-resource and its line in stations; nothing else to touch.

@export var stations: Array[TestStation] = []
