@tool
class_name LeaderBase
extends Node
## Base script for leader class scenes. All class-specific trait pools and XP weights in Inspector.

@export_group("Class")
@export var leader_class: int = 0  # LeaderClass.Class
@export var class_display_name: String = ""

@export_group("Progression Settings")
@export var max_level: int = 10
@export var veteran_level: int = 5
@export var destiny_level: int = 10

@export_group("Starting Trait Pool")
@export var possible_background_traits: Array = []  # Array[LeaderTrait]

@export_group("Level Trait Pool")
@export var level_trait_pool: Array = []

@export_group("Veteran Trait Pool")
@export var veteran_trait_pool: Array = []

@export_group("Destiny Trait Pool")
@export var destiny_trait_pool: Array = []

@export_group("XP Source Weights")
@export var xp_per_fleet_combat: float = 20.0
@export var xp_per_planet_month: float = 3.0
@export var xp_per_survey_complete: float = 30.0
@export var xp_per_megastructure_stage: float = 80.0

@export_group("Balancing")
@export var global_xp_multiplier: float = 1.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if possible_background_traits.is_empty():
		warnings.append("No background traits defined — leaders of this class will spawn with no starting trait")
	if level_trait_pool.size() < 4:
		warnings.append("Level trait pool has fewer than 4 traits — choices will be limited")
	if veteran_trait_pool.size() < 3:
		warnings.append("Veteran trait pool needs at least 3 entries for meaningful choice")
	if destiny_trait_pool.size() < 3:
		warnings.append("Destiny trait pool needs at least 3 entries")
	return warnings
