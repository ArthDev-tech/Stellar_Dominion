class_name ResourceStation
extends RefCounted
## A station that collects resource deposits from a stellar body (star, planet, or asteroid belt).
## Built by construction ships; one per body per empire.

var empire_id: int
var system_id: int
var name_key: String
## "star" | "planet" | "belt"
var body_type: String = ""
## Planet index or belt index; for star use 0
var body_index: int = 0

## Build cost and time (used when construction ship is ordered to build)
const BUILD_COST_ENERGY: float = 100.0
const BUILD_COST_MINERALS: float = 50.0
const BUILD_TIME_MONTHS: int = 6

func _init(p_empire_id: int, p_system_id: int, p_name_key: String, p_body_type: String, p_body_index: int) -> void:
	empire_id = p_empire_id
	system_id = p_system_id
	name_key = p_name_key
	body_type = p_body_type
	body_index = p_body_index


static func get_build_cost() -> Dictionary:
	var cost: Dictionary = {}
	cost[GameResources.ResourceType.ENERGY] = BUILD_COST_ENERGY
	cost[GameResources.ResourceType.MINERALS] = BUILD_COST_MINERALS
	return cost
