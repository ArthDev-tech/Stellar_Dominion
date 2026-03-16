class_name Planet
extends RefCounted
## A planet or moon in a star system.

enum PlanetType { BARREN, DESERT, ARCTIC, TROPICAL, CONTINENTAL, OCEAN, GAIA, GAS_GIANT, LAVA, HOTHOUSE }

var id: int
var name_key: String  ## For localization; can display as-is for now
var type: PlanetType
var habitability: float  ## 0.0 to 1.0 for player species
var size: int  ## 1-25 or similar; affects districts/jobs later
var orbit_radius: float  ## For visual placement around star
var orbit_angle: float   ## Angle in radians
## Resource deposits (monthly yield when exploited). Array of { "resource_type": GameResources.ResourceType, "amount": float }
var deposits: Array = []

func _init(
	p_id: int = 0,
	p_name_key: String = "",
	p_type: PlanetType = PlanetType.BARREN,
	p_habitability: float = 0.0,
	p_size: int = 12,
	p_orbit_radius: float = 100.0,
	p_orbit_angle: float = 0.0
) -> void:
	id = p_id
	name_key = p_name_key
	type = p_type
	habitability = p_habitability
	size = p_size
	orbit_radius = p_orbit_radius
	orbit_angle = p_orbit_angle
