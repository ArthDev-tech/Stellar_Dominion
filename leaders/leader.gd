class_name Leader
extends RefCounted
## Legacy compatibility type for empire.leaders and LeaderManager. Mirrors LeaderInstance for old API.

enum LeaderType {
	RULER,
	GOVERNOR,
	SCIENTIST,
	ADMIRAL,
	GENERAL,
}

var id: int = -1
var empire_id: int = -1
var leader_type: int = -1
var name_key: String = ""
var level: int = 1
var assigned_to_research: bool = false
var trait_ids: Array = []


func _init(p_id: int = -1, p_empire_id: int = -1, p_leader_type: int = -1, p_name_key: String = "") -> void:
	id = p_id
	empire_id = p_empire_id
	leader_type = p_leader_type
	name_key = p_name_key


static func get_type_name(leader_type: int) -> String:
	match leader_type:
		LeaderType.RULER: return "RULER"
		LeaderType.GOVERNOR: return "GOVERNOR"
		LeaderType.SCIENTIST: return "SCIENTIST"
		LeaderType.ADMIRAL: return "ADMIRAL"
		LeaderType.GENERAL: return "GENERAL"
		_: return "?"
