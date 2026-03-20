class_name DistrictDefinitionResource
extends Resource
## Inspector-editable definition for a district type. Used by planet view and Colony.
## One .tres per district in data/planet_districts/. Scenes in scenes/planet/districts/ reference these.

@export_group("Identity")
@export var id: String = ""
@export var name_key: String = ""
@export_multiline var description: String = ""

@export_group("Cost")
## Construction cost: resource type (int) -> amount.
@export var cost: Dictionary = {}

@export_group("Jobs")
## Job id (String) -> number of slots per district. E.g. { "technician": 2 }
@export var jobs: Dictionary = {}

@export_group("Housing")
@export var housing: int = 0

@export_group("Display")
## Path to icon texture for the district.
@export var icon_path: String = ""


func to_dict() -> Dictionary:
	var out_cost: Dictionary = {}
	for k in cost:
		out_cost[str(k)] = cost[k]
	return {
		"id": id,
		"name_key": name_key,
		"housing": housing,
		"jobs": jobs.duplicate(),
		"cost": out_cost,
	}
