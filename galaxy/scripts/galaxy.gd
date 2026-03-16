class_name Galaxy
extends RefCounted
## Root galaxy data: list of star systems and hyperlane edges.

var systems: Array[StarSystem] = []
var hyperlanes: Array[Hyperlane] = []
var wormhole_pairs: Array = []  ## Each element: { "from_id": int, "to_id": int }
var anomalies: Array[Anomaly] = []
var player_home_system_id: int = -1
var empire_home_system_ids: Array[int] = []
var fallen_empires: Array[FallenEmpire] = []


func get_system_by_id(system_id: int) -> StarSystem:
	for s in systems:
		if s.id == system_id:
			return s
	return null
