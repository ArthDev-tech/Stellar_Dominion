class_name Empire
extends RefCounted
## One empire (player or AI): identity, home system, resources, colonies.

var id: int
var name_key: String
var home_system_id: int
var color: Color
var is_player: bool
var is_ai: bool
var resources: GameResources
var colonies: Array[Colony] = []
var completed_tech_ids: Array[String] = []
var current_research_tech_id: String = ""
var research_progress: float = 0.0
var research_queue: Array = []  ## Ordered tech ids to research after current (prerequisites first when queued from tree)
var leaders: Array[Leader] = []
var space_stations: Array[SpaceStation] = []  ## Stations created when colonies build orbital station
var resource_stations: Array = []  ## Stations built by construction ships (ResourceStation); collect deposits from stellar bodies
var ships: Array[Ship] = []  ## Ships built at stations (exist in a system)
var precursor_progress: Dictionary = {}  ## precursor_id -> count of anomalies found


func _init(
	p_id: int = 0,
	p_name_key: String = "",
	p_home_system_id: int = -1,
	p_color: Color = Color.WHITE,
	p_is_player: bool = false,
	p_is_ai: bool = true
) -> void:
	id = p_id
	name_key = p_name_key
	home_system_id = p_home_system_id
	color = p_color
	is_player = p_is_player
	is_ai = p_is_ai
	resources = GameResources.new()
	# Starting resources
	resources.set_amount(GameResources.ResourceType.ENERGY, 100.0)
	resources.set_amount(GameResources.ResourceType.MINERALS, 100.0)
	resources.set_amount(GameResources.ResourceType.FOOD, 50.0)


func add_colony(colony: Colony) -> void:
	colonies.append(colony)


func get_colony(system_id: int, planet_index: int) -> Colony:
	for col in colonies:
		if col.system_id == system_id and col.planet_index == planet_index:
			return col
	return null


func get_stations_in_system(system_id: int) -> Array:
	var out: Array = []
	for s in space_stations:
		if (s as SpaceStation).system_id == system_id:
			out.append(s)
	return out


func get_station_at(system_id: int, planet_index: int) -> SpaceStation:
	for s in space_stations:
		var st: SpaceStation = s as SpaceStation
		if st.system_id == system_id and st.planet_index == planet_index:
			return st
	return null


## Call when a colony builds orbital_station; creates the station if none at that colony.
func ensure_station_at_colony(system_id: int, planet_index: int, station_name_key: String) -> SpaceStation:
	var existing: SpaceStation = get_station_at(system_id, planet_index)
	if existing != null:
		return existing
	var st := SpaceStation.new(id, system_id, planet_index, station_name_key)
	space_stations.append(st)
	return st


func get_resource_station_at_body(system_id: int, body_type: String, body_index: int):
	for rs in resource_stations:
		if rs.system_id == system_id and rs.body_type == body_type and rs.body_index == body_index:
			return rs
	return null


func get_resource_stations_in_system(system_id: int) -> Array:
	var out: Array = []
	for rs in resource_stations:
		if rs.system_id == system_id:
			out.append(rs)
	return out


func add_resource_station(station) -> void:
	resource_stations.append(station)
