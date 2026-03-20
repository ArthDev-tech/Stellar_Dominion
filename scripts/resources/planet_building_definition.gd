class_name PlanetBuildingDefinitionResource
extends Resource
## Inspector-editable definition for a planet building. Used by planet view and Colony.
## One .tres per building in data/planet_buildings/. Scenes in scenes/planet/buildings/ reference these.

@export_group("Identity")
@export var id: String = ""
@export var name_key: String = ""
@export_multiline var description: String = ""

@export_group("Cost")
## Construction cost: resource type (int) -> amount. Use GameResources.ResourceType.
@export var cost: Dictionary = {}

@export_group("Jobs")
## Job id (String) -> number of slots. E.g. { "miner": 2 }
@export var jobs: Dictionary = {}

@export_group("Upkeep")
## Monthly upkeep: resource type (int) -> amount. Leave empty if jobs define upkeep.
@export var upkeep: Dictionary = {}

@export_group("Slots")
@export var building_slots: int = 1
## "planetary", "orbital", or "district_amplifier"
@export var slot_type: String = "planetary"
## For district_amplifier: "energy", "mining", or "farming"
@export var district_type: String = ""

@export_group("Display")
## Path to icon texture, e.g. res://assets/buildings/ore_mine.png
@export var icon_path: String = ""


func to_dict() -> Dictionary:
	var out_cost: Dictionary = {}
	for k in cost:
		out_cost[str(k)] = cost[k]
	return {
		"id": id,
		"name_key": name_key,
		"cost": out_cost,
		"jobs": jobs.duplicate(),
		"upkeep": upkeep.duplicate(),
		"building_slots": building_slots,
		"slot_type": slot_type,
		"district_type": district_type,
		"icon": icon_path,
	}
