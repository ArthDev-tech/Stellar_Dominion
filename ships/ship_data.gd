class_name ShipData
extends Resource
## Per-ship display/summary data for fleet composition and fleet panel.

@export var ship_name: String = ""
@export var ship_class: String = ""  # "corvette" | "destroyer" | "cruiser" | "battleship" | "titan" | "science" | "constructor" | "transport"
@export var combat_power: float = 0.0
@export var hull_current: float = 100.0
@export var hull_max: float = 100.0
## Galaxy map selection identity (stable after icon rebuild)
@export var galaxy_system_id: int = -1
@export var galaxy_empire_id: int = -1
## Unique per Ship ref; disambiguates multiple same name_key in one system (e.g. two Construction Ships).
@export var galaxy_selection_instance_id: int = 0
## Drive modifier for transit time (1.0 = baseline). Used for display and path tooltip.
@export var transit_time_modifier: float = 1.0
@export var transit_days_remaining: int = 0
@export var transit_days_total: int = 0


func matches_ship(ship: Ship) -> bool:
	if ship == null or galaxy_empire_id != ship.empire_id:
		return false
	if galaxy_selection_instance_id != 0:
		return ship.get_instance_id() == galaxy_selection_instance_id
	if ship_name != ship.name_key:
		return false
	if ship.in_hyperlane:
		return galaxy_system_id == ship.system_id
	return galaxy_system_id == ship.system_id


func duplicate_selection() -> ShipData:
	var c := ShipData.new()
	c.ship_name = ship_name
	c.ship_class = ship_class
	c.combat_power = combat_power
	c.hull_current = hull_current
	c.hull_max = hull_max
	c.galaxy_system_id = galaxy_system_id
	c.galaxy_empire_id = galaxy_empire_id
	c.galaxy_selection_instance_id = galaxy_selection_instance_id
	c.transit_time_modifier = transit_time_modifier
	c.transit_days_remaining = transit_days_remaining
	c.transit_days_total = transit_days_total
	return c
