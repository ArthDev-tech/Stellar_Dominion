extends Node
## Holds all empires; populated when galaxy is generated.
## Access via autoload: EmpireManager

var empires: Array[Empire] = []

# Default colors for empires (player first, then AI)
const EMPIRE_COLORS: Array[Color] = [
	Color(0.2, 0.6, 1.0),   # Player - blue
	Color(1.0, 0.35, 0.3),   # AI 1 - red
	Color(0.3, 0.85, 0.4),   # AI 2 - green
	Color(0.95, 0.8, 0.2),   # AI 3 - yellow
	Color(0.7, 0.4, 1.0),    # AI 4 - purple
]

const EMPIRE_NAMES: Array[String] = [
	"Human Coalition",
	"Xelara Combine",
	"Korathi Dominion",
	"Sovran Hegemony",
	"Vex Collective",
]

## Extra resources granted to the player when dev_testing_start is true.
const DEV_TESTING_BONUS: Dictionary = {
	GameResources.ResourceType.ENERGY: 10000.0,
	GameResources.ResourceType.MINERALS: 10000.0,
	GameResources.ResourceType.FOOD: 5000.0,
	GameResources.ResourceType.ALLOYS: 5000.0,
	GameResources.ResourceType.RESEARCH: 5000.0,
	GameResources.ResourceType.CONSUMER_GOODS: 2000.0,
	GameResources.ResourceType.INFLUENCE: 500.0,
	GameResources.ResourceType.UNITY: 500.0,
	GameResources.ResourceType.GAS: 500.0,
	GameResources.ResourceType.ICE: 500.0,
	GameResources.ResourceType.BIOMASS: 500.0,
	GameResources.ResourceType.VOLATILE_MOTES: 300.0,
	GameResources.ResourceType.EXOTIC_GASES: 300.0,
	GameResources.ResourceType.RARE_CRYSTALS: 300.0,
}


func create_empires_from_galaxy(galaxy: Galaxy, dev_testing_start: bool = false) -> void:
	empires.clear()
	if galaxy == null or galaxy.empire_home_system_ids.is_empty():
		return
	for i in galaxy.empire_home_system_ids.size():
		var system_id: int = galaxy.empire_home_system_ids[i]
		var name_key: String = EMPIRE_NAMES[i] if i < EMPIRE_NAMES.size() else "Empire_%d" % i
		var col: Color = EMPIRE_COLORS[i] if i < EMPIRE_COLORS.size() else Color(0.5, 0.5, 0.5)
		var is_player: bool = (i == 0)
		var e := Empire.new(i, name_key, system_id, col, is_player, not is_player)
		empires.append(e)
		# Starting colony on first habitable planet in home system
		var sys: StarSystem = galaxy.get_system_by_id(system_id)
		if sys != null:
			for p_idx in sys.planets.size():
				if sys.planets[p_idx].habitability > 0.0:
					var is_homeworld: bool = (i == 0)  # First empire is player; only homeworld gets 9000 pop + full setup
					var colony := Colony.new(e.id, system_id, p_idx, is_homeworld)
					e.add_colony(colony)
					_setup_starting_orbital_and_ships(e, sys, system_id, p_idx)
					break
		# Player starts with one scientist assigned to research
		if is_player and LeaderManager != null:
			var sci: Leader = LeaderManager.recruit_leader(e, Leader.LeaderType.SCIENTIST)
			LeaderManager.assign_scientist_to_research(e, sci)

	if dev_testing_start:
		var player: Empire = get_player_empire()
		if player != null:
			_grant_dev_resources(player)


func _grant_dev_resources(empire: Empire) -> void:
	for res_type in DEV_TESTING_BONUS:
		var amount: float = DEV_TESTING_BONUS[res_type]
		empire.resources.add_amount(res_type as GameResources.ResourceType, amount)


func get_empire(empire_id: int) -> Empire:
	for e in empires:
		if e.id == empire_id:
			return e
	return null


func get_player_empire() -> Empire:
	for e in empires:
		if e.is_player:
			return e
	return null


func get_empire_for_home_system(system_id: int) -> Empire:
	for e in empires:
		if e.home_system_id == system_id:
			return e
	return null


func get_home_system_ids() -> Array[int]:
	var out: Array[int] = []
	for e in empires:
		out.append(e.home_system_id)
	return out


## Give the starting colony an orbital station with a small shipyard and three starting ships.
func _setup_starting_orbital_and_ships(empire: Empire, sys: StarSystem, system_id: int, planet_index: int) -> void:
	var colony: Colony = empire.get_colony(system_id, planet_index)
	if colony == null or planet_index < 0 or planet_index >= sys.planets.size():
		return
	# Orbital station + small shipyard on the colony
	colony.orbital_buildings.append("orbital_station")
	var planet: Planet = sys.planets[planet_index]
	var station_name: String = planet.name_key + " Station"
	var station: SpaceStation = empire.ensure_station_at_colony(system_id, planet_index, station_name)
	station.station_buildings.append("small_shipyard")
	# Spawn position near the station (same logic as EconomyManager ship spawn)
	var base_pos: Vector2 = Vector2(cos(planet.orbit_angle), sin(planet.orbit_angle)) * planet.orbit_radius
	base_pos += base_pos.normalized() * 14.0
	const SPREAD_RADIUS := 10.0
	var starting_designs: Array[Dictionary] = [
		{ "id": "science_ship", "name": "Science Ship" },
		{ "id": "construction_ship", "name": "Construction Ship" },
		{ "id": "corvette", "name": "Corvette" },
	]
	for i in starting_designs.size():
		var design: Dictionary = starting_designs[i]
		var ship: Ship = Ship.new(empire.id, system_id, design.id, design.name)
		var angle_offset: float = float(i) * TAU / 10.0
		ship.position_in_system = base_pos + Vector2(cos(angle_offset), sin(angle_offset)) * SPREAD_RADIUS
		empire.ships.append(ship)
