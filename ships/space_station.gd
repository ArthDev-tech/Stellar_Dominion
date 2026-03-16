class_name SpaceStation
extends RefCounted
## A space station in a system, owned by an empire. Built when a colony builds an orbital station.
## Has sub-tabs: Command, Defenses, Shipyard (build queue).

var empire_id: int
var system_id: int
var planet_index: int  ## Which planet's orbit (colony that built it)
var name_key: String
## Shipyard: queue of builds. Each entry: { "design_id": String, "progress_months": int }
var ship_build_queue: Array = []
## Station building slots (modules): built building ids.
var station_buildings: Array = []

const STATION_BUILDING_SLOTS: int = 6


func _init(p_empire_id: int, p_system_id: int, p_planet_index: int, p_name_key: String) -> void:
	empire_id = p_empire_id
	system_id = p_system_id
	planet_index = p_planet_index
	name_key = p_name_key


func get_station_building_slots() -> int:
	return STATION_BUILDING_SLOTS


func get_shipyard_count() -> int:
	var n: int = 0
	for bid in station_buildings:
		if bid == "small_shipyard" or bid == "medium_shipyard":
			n += 1
	return n


func queue_ship(design_id: String) -> void:
	ship_build_queue.append({ "design_id": design_id, "progress_months": 0 })


func add_building(building_id: String, empire: Empire) -> bool:
	if empire == null or station_buildings.size() >= STATION_BUILDING_SLOTS:
		return false
	var defs: Array = _load_building_defs()
	var def: Dictionary = {}
	for d in defs:
		if d.get("id", "") == building_id and d.get("station_module", false):
			def = d
			break
	if def.is_empty():
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	station_buildings.append(building_id)
	return true


func _load_building_defs() -> Array:
	return Colony.get_all_building_defs()


func _cost_dict_from_json(cost_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cost_json:
		var rt: int = int(key)
		if rt >= 0 and rt < GameResources.ResourceType.LAST:
			out[rt as GameResources.ResourceType] = float(cost_json[key])
	return out
