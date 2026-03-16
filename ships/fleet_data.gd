class_name FleetData
extends Resource
## Fleet identity and composition for galaxy icon and fleet panel.

@export_group("Identity")
@export var fleet_id: String = ""
@export var fleet_name: String = ""
@export var owner_empire_id: String = ""
@export var current_system_id: String = ""

@export_group("Composition")
@export var ships: Array[ShipData] = []


func get_ship_count_by_class(ship_class: String) -> int:
	var count: int = 0
	for s in ships:
		if s != null and s.ship_class == ship_class:
			count += 1
	return count


func get_total_power() -> float:
	var total: float = 0.0
	for s in ships:
		if s != null:
			total += s.combat_power
	return total
