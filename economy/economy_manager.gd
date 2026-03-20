extends Node
## Processes monthly tick: colony production, growth, station ship builds. Call process_month() when game date advances.
## Access via autoload: EconomyManager

signal ship_built(system_id: int)  ## Emitted when a ship is completed at a station (so system view can refresh)
signal resource_station_built(system_id: int)  ## Emitted when a construction ship finishes building a resource station

var _ResourceStation: GDScript = preload("res://ships/resource_station.gd") as GDScript
const RESOURCE_STATION_BUILD_MONTHS: int = 6

# --- Ship movement ---
@export_group("Ship movement")
@export var base_transit_days: int = 180  ## In-game days per hyperlane jump (before drive modifier).

# --- Manpower (ES2-style) ---
@export_group("Manpower")
@export var manpower_from_food_percent: float = 0.10
@export var manpower_per_soldier_per_month: float = 2.0
@export var base_manpower_cap: float = 500.0
@export var per_system_manpower_cap: float = 200.0


func _get_design_build_time_months(design_id: String) -> int:
	if ShipDesignManager != null:
		return ShipDesignManager.get_design_build_time_months(design_id)
	return 12


func _get_design_name(design_id: String) -> String:
	if ShipDesignManager != null:
		return ShipDesignManager.get_design_name(design_id)
	return design_id


## Returns display type for galaxy map: "science", "construction", or "military".
func get_ship_display_type(design_id: String) -> String:
	if ShipDesignManager != null:
		return ShipDesignManager.get_ship_display_type(design_id)
	return "construction"


func process_month() -> void:
	for e in EmpireManager.empires:
		_process_empire(e)
	if GovernmentManager != null:
		var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
		GovernmentManager.process_monthly_tick(player_emp)


func _process_empire(empire: Empire) -> void:
	var research_points: float = 0.0
	var income_this_month: Dictionary = {}
	var total_soldiers: int = 0
	for r in range(GameResources.ResourceType.LAST):
		income_this_month[r] = 0.0
	for col in empire.colonies:
		var sys: StarSystem = GalaxyManager.get_system(col.system_id) if GalaxyManager != null else null
		var planet: Planet = null
		if sys != null and col.planet_index >= 0 and col.planet_index < sys.planets.size():
			planet = sys.planets[col.planet_index]
		col.tick(planet)
		var filled: Dictionary = col.assign_pops_to_jobs()
		total_soldiers += filled.get("soldier", 0)
		research_points += col.get_research_output(filled)
		var produced: Dictionary = col.produce(filled)
		for res_type in produced:
			if res_type == 4:
				continue  # Research goes to tech progress, not stored
			empire.resources.add_amount(res_type as GameResources.ResourceType, produced[res_type])
			income_this_month[res_type] = income_this_month.get(res_type, 0.0) + produced[res_type]
	if ResearchManager != null and research_points > 0:
		ResearchManager.add_research_progress(empire, research_points)
		income_this_month[GameResources.ResourceType.RESEARCH] = research_points
	_process_station_builds(empire)
	_process_construction_orders(empire)
	var station_income: Dictionary = _process_resource_station_income(empire)
	for r in station_income:
		empire.resources.add_amount(r as GameResources.ResourceType, station_income[r])
		income_this_month[r] = income_this_month.get(r, 0.0) + station_income[r]
	_process_manpower(empire, income_this_month, total_soldiers)
	for r in range(GameResources.ResourceType.LAST):
		empire.resources.income_per_month[r] = income_this_month.get(r, 0.0)
	if LeaderManager != null:
		LeaderManager.process_monthly_tick(empire)
	if CouncilManager != null:
		CouncilManager.process_monthly_tick(empire.id)


func _process_station_builds(empire: Empire) -> void:
	for st in empire.space_stations:
		var station: SpaceStation = st as SpaceStation
		var shipyard_count: int = station.get_shipyard_count()
		if shipyard_count <= 0 or station.ship_build_queue.is_empty():
			continue
		for _i in range(shipyard_count):
			if station.ship_build_queue.is_empty():
				break
			var entry: Dictionary = station.ship_build_queue[0]
			var design_id: String = entry.get("design_id", "")
			var progress: int = int(entry.get("progress_months", 0))
			progress += 1
			entry["progress_months"] = progress
			var required: int = _get_design_build_time_months(design_id)
			if progress >= required:
				station.ship_build_queue.pop_front()
				var name_key: String = _get_design_name(design_id)
				var ship := Ship.new(empire.id, station.system_id, design_id, name_key)
				if ShipDesignManager != null:
					ship.transit_time_modifier = ShipDesignManager.get_transit_time_modifier_for_design(design_id)
				var ships_in_system: int = 0
				for s in empire.ships:
					if (s as Ship).system_id == station.system_id:
						ships_in_system += 1
				ship.position_in_system = _get_station_spawn_position(station, ships_in_system)
				empire.ships.append(ship)
				ship_built.emit(station.system_id)


func _get_station_spawn_position(station: SpaceStation, spread_index: int) -> Vector2:
	if GalaxyManager == null:
		return Vector2(55.0, 0.0)
	var sys: StarSystem = GalaxyManager.get_system(station.system_id)
	if sys == null or station.planet_index < 0 or station.planet_index >= sys.planets.size():
		return Vector2(55.0, 0.0)
	var planet: Planet = sys.planets[station.planet_index]
	var pos: Vector2 = Vector2(cos(planet.orbit_angle), sin(planet.orbit_angle)) * planet.orbit_radius
	pos += pos.normalized() * 14.0  # Just outside station
	const SPREAD_RADIUS := 10.0
	var angle_offset: float = float(spread_index) * TAU / 10.0
	pos += Vector2(cos(angle_offset), sin(angle_offset)) * SPREAD_RADIUS
	return pos


func _process_construction_orders(empire: Empire) -> void:
	if GalaxyManager == null:
		return
	for ship in empire.ships:
		var s: Ship = ship as Ship
		if s.design_id != "construction_ship" or not s.has_build_order():
			continue
		var order_system_id: int = s.build_order.get("system_id", -1)
		if s.system_id != order_system_id:
			continue
		var sys: StarSystem = GalaxyManager.get_system(order_system_id)
		if sys == null:
			continue
		var body_type: String = s.build_order.get("body_type", "")
		var body_index: int = s.build_order.get("body_index", 0)
		var body_pos: Vector2 = s.get_build_target_position_in_system(sys, body_type, body_index)
		var dist_sq: float = s.position_in_system.distance_squared_to(body_pos)
		if dist_sq > s.ARRIVAL_DISTANCE_SQ:
			continue
		var progress: int = s.build_order.get("progress_months", 0)
		progress += 1
		s.build_order["progress_months"] = progress
		var build_time: int = s.build_order.get("build_time_months", RESOURCE_STATION_BUILD_MONTHS)
		if progress < build_time:
			continue
		# Complete: create resource station
		var name_key: String = _get_resource_station_name(sys, body_type, body_index)
		var station = _ResourceStation.new(empire.id, order_system_id, name_key, body_type, body_index)
		empire.add_resource_station(station)
		s.build_order = {}
		s.target_position = Vector2(-99999.0, -99999.0)
		resource_station_built.emit(order_system_id)


func _get_resource_station_name(sys: StarSystem, body_type: String, body_index: int) -> String:
	if body_type == "star":
		return sys.name_key + " Solar Collector"
	if body_type == "planet" and body_index >= 0 and body_index < sys.planets.size():
		return sys.planets[body_index].name_key + " Mining Station"
	if body_type == "belt" and body_index >= 0 and body_index < sys.asteroid_belts.size():
		return sys.asteroid_belts[body_index].name_key + " Mining Station"
	return "Resource Station"


func _process_resource_station_income(empire: Empire) -> Dictionary:
	var income: Dictionary = {}
	for r in range(GameResources.ResourceType.LAST):
		income[r] = 0.0
	if GalaxyManager == null:
		return income
	for rs in empire.resource_stations:
		var sys: StarSystem = GalaxyManager.get_system(rs.system_id)
		if sys == null:
			continue
		var deposits: Array = []
		if rs.body_type == "star":
			deposits = sys.star_deposits
		elif rs.body_type == "planet" and rs.body_index >= 0 and rs.body_index < sys.planets.size():
			deposits = sys.planets[rs.body_index].deposits
		elif rs.body_type == "belt" and rs.body_index >= 0 and rs.body_index < sys.asteroid_belts.size():
			deposits = sys.asteroid_belts[rs.body_index].deposits
		for d in deposits:
			var rt: int = d.get("resource_type", 0)
			var amt: float = d.get("amount", 0.0)
			if rt >= 0 and rt < GameResources.ResourceType.LAST:
				income[rt] = income.get(rt, 0.0) + amt
	return income


func _process_manpower(empire: Empire, income_this_month: Dictionary, total_soldiers: int) -> void:
	var food_income: float = income_this_month.get(GameResources.ResourceType.FOOD, 0.0)
	var manpower_from_food: float = food_income * manpower_from_food_percent
	var manpower_from_soldiers: float = float(total_soldiers) * manpower_per_soldier_per_month
	var manpower_delta: float = manpower_from_food + manpower_from_soldiers
	empire.resources.add_amount(GameResources.ResourceType.MANPOWER, manpower_delta)
	var cap: float = get_manpower_cap(empire)
	var current: float = empire.resources.get_amount(GameResources.ResourceType.MANPOWER)
	if current > cap:
		empire.resources.set_amount(GameResources.ResourceType.MANPOWER, cap)
	income_this_month[GameResources.ResourceType.MANPOWER] = manpower_delta


## Maximum manpower reserve; scales with number of systems the empire controls (colonies).
func get_manpower_cap(empire: Empire) -> float:
	var system_count: int = 0
	var seen: Dictionary = {}
	for col in empire.colonies:
		var sid: int = col.system_id
		if not seen.get(sid, false):
			seen[sid] = true
			system_count += 1
	return base_manpower_cap + per_system_manpower_cap * float(system_count)


func process_ship_movement(delta_days: float = 1.0) -> void:
	for e in EmpireManager.empires:
		for s in e.ships:
			(s as Ship).tick_movement(delta_days)
