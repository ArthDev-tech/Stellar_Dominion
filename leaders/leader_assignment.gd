class_name LeaderAssignment
extends RefCounted
## Where a leader is assigned: idle, planet, fleet, council, etc.

enum Type {
	IDLE,
	PLANET,
	SECTOR,
	FLEET,
	ARMY,
	SURVEY,
	COUNCIL,
}

var type: Type = Type.IDLE
var target_id: int = -1
var council_position_id: String = ""
var months_in_assignment: int = 0
