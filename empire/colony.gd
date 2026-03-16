class_name Colony
extends RefCounted
## Runtime state for a colonized planet: pops, districts, buildings, jobs.

var empire_id: int
var system_id: int
var planet_index: int  ## Index in StarSystem.planets
## Abstract population (e.g. 9000 ≈ 20B for starting world). Growth adds 1 per 100 progress.
var pop_count: int = 1
var growth_progress: float = 0.0
var district_counts: Dictionary = {}  ## district_id (String) -> count (int)
var buildings: Array[String] = []  ## planetary building id strings; first is always "capital"
var orbital_buildings: Array[String] = []  ## orbital building id strings (space stations, shipyards, etc.)
## Planet-wide city specializations: exactly 3 slots (not per district).
var city_specializations: Array = []
## Buildings in each city specialization's 4 slots; index = spec slot 0..2, value = array of building_id (max 4).
var city_specialization_buildings: Array = [[], [], []]
## Resource district types can be "specialized" once to unlock 4 amplifier slots; building districts only adds jobs.
var district_amplifier_specialized: Dictionary = {"energy": false, "mining": false, "farming": false}
## Buildings that amplify resource district output: "energy" | "mining" | "farming" -> array of building_id.
var district_amplifier_buildings: Dictionary = {"energy": [], "mining": [], "farming": []}

const STARTING_POPULATION: int = 9000
const GROWTH_PER_MONTH_BASE: float = 3.0
const GROWTH_THRESHOLD: float = 100.0
const BASE_BUILDING_SLOTS: int = 9
const BASE_ORBITAL_SLOTS: int = 3
const BUILDING_SLOTS_PER_CITY_SPECIALIZATION: int = 4
const CITY_SPECIALIZATION_SLOTS_TOTAL: int = 3
const DISTRICT_AMPLIFIER_SLOTS_PER_SPECIALIZATION: int = 4
const RESOURCE_DISTRICT_SPECIALIZE_COST_ENERGY: int = 239
const RESOURCE_DISTRICT_SPECIALIZE_COST_MINERALS: int = 1000
const DISTRICT_AMPLIFIER_MULTIPLIER: float = 0.2  ## +20% output per amplifier building for that district type
## Population cap is housing-based (Stellaris-style). Planet size only limits districts via get_max_districts().
const POP_PER_HOUSING: int = 400  ## Cap = housing * this (e.g. 50 housing → 20_000 cap).
const POP_PER_PLANET_SIZE: int = 1000  ## Unused for cap; kept for reference. Districts limited by planet.size.
## Civilians (pops not in jobs) still contribute: energy per civilian per month.
const CIVILIAN_ENERGY_PER_POP: float = 0.02

# Fallback when job_balance.tres is missing. job_id -> { "resource": int, "amount": float, "upkeep": { int: float } }
const JOB_PRODUCTION: Dictionary = {
	"technician": { "resource": 0, "amount": 0.04 },
	"miner": { "resource": 1, "amount": 0.04 },
	"farmer": { "resource": 2, "amount": 0.04 },
	"researcher": { "resource": 4, "amount": 0.03 },
	"metallurgist": { "resource": 3, "amount": 0.02, "upkeep": { 1: 0.01 } },
	"clerk": { "resource": 0, "amount": 0.01 },
	"ruler": {},
	"enforcer": {},
	"artisan": { "resource": 0, "amount": 0.02 },
	"acolyte": { "resource": 7, "amount": 0.02 },
	"chemist": { "resource": 26, "amount": 0.02 },
	"soldier": { "resource": 32, "amount": 0.005 },
}

static var _job_balance: JobBalanceConfig = null


static func _get_job_balance_config() -> JobBalanceConfig:
	if _job_balance != null:
		return _job_balance
	if ProjectPaths == null:
		return null
	var res: Resource = ResourceLoader.load(ProjectPaths.DATA_JOB_BALANCE)
	if res is JobBalanceConfig:
		_job_balance = res as JobBalanceConfig
	return _job_balance


## Returns production dict from config or JOB_PRODUCTION fallback. Shape: { "resource": int, "amount": float, "upkeep": { int: float } }
func _get_job_production_dict(job_id: String) -> Dictionary:
	var config: JobBalanceConfig = _get_job_balance_config()
	if config != null and config.job_definitions != null:
		for def in config.job_definitions:
			if def != null and def.job_id == job_id:
				var upkeep_int: Dictionary = {}
				for k in def.upkeep:
					var rt: int = int(k) if str(k).is_valid_int() else int(k)
					upkeep_int[rt] = float(def.upkeep[k])
				var out: Dictionary = { "resource": def.output_resource_type, "amount": def.output_amount }
				if upkeep_int.size() > 0:
					out["upkeep"] = upkeep_int
				return out
	return JOB_PRODUCTION.get(job_id, {})


## For Economy tab UI: name_key, output_resource_type, output_amount, upkeep (int -> float).
func get_job_definition_for_display(job_id: String) -> Dictionary:
	var config: JobBalanceConfig = _get_job_balance_config()
	if config != null and config.job_definitions != null:
		for def in config.job_definitions:
			if def != null and def.job_id == job_id:
				var upkeep_copy: Dictionary = {}
				for k in def.upkeep:
					var rt: int = int(k) if str(k).is_valid_int() else int(k)
					upkeep_copy[rt] = float(def.upkeep[k])
				return {
					"name_key": def.name_key,
					"output_resource_type": def.output_resource_type,
					"output_amount": def.output_amount,
					"upkeep": upkeep_copy,
				}
	var fallback: Dictionary = JOB_PRODUCTION.get(job_id, {})
	return {
		"name_key": job_id.capitalize(),
		"output_resource_type": int(fallback.get("resource", -1)),
		"output_amount": float(fallback.get("amount", 0.0)),
		"upkeep": fallback.get("upkeep", {}).duplicate(),
	}


func _init(p_empire_id: int, p_system_id: int, p_planet_index: int, is_starting_homeworld: bool = false) -> void:
	empire_id = p_empire_id
	system_id = p_system_id
	planet_index = p_planet_index
	buildings.append("capital")
	if is_starting_homeworld:
		# Starting planet: 9000 pop (abstract ~20B), 3 city + 2 production districts, planetary authority + science complex
		pop_count = STARTING_POPULATION
		buildings.append("planetary_authority")
		buildings.append("planetary_science_complex")
		district_counts["city"] = 3
		district_counts["energy"] = 1
		district_counts["mining"] = 1
	else:
		# New colony: minimal pop and one district of each type
		district_counts["city"] = 1
		district_counts["energy"] = 1


func get_max_districts(planet: Planet) -> int:
	return planet.size if planet != null else 10


## Max population cap for this colony (housing-based, Stellaris-style). Uses get_total_housing(); planet size does not set cap.
func get_max_population(planet: Planet) -> int:
	var housing: int = get_total_housing()
	if housing <= 0:
		return POP_PER_HOUSING  ## Minimum cap when no districts yet (safeguard).
	return housing * POP_PER_HOUSING


## Number of pops currently in jobs (sum of all filled job slots).
func get_employed_count() -> int:
	var filled: Dictionary = assign_pops_to_jobs()
	var n: int = 0
	for _job_id in filled:
		n += filled[_job_id]
	return n


## Pops not in jobs; they still produce a small civilian benefit (e.g. energy).
func get_civilian_count() -> int:
	return maxi(0, pop_count - get_employed_count())


func get_total_districts() -> int:
	var total: int = 0
	for _id in district_counts:
		total += district_counts[_id]
	return total


func get_building_slots() -> int:
	_ensure_city_specializations_synced()
	var specialized: int = 0
	for s in city_specializations:
		if (s is String) and (s as String).length() > 0:
			specialized += 1
	return BASE_BUILDING_SLOTS + specialized * BUILDING_SLOTS_PER_CITY_SPECIALIZATION


func get_orbital_slots() -> int:
	return BASE_ORBITAL_SLOTS


func get_total_housing() -> int:
	var h: int = 0
	var d_data: Array = _load_district_defs()
	for d in d_data:
		var id_str: String = d.get("id", "")
		var cnt: int = district_counts.get(id_str, 0)
		h += cnt * int(d.get("housing", 0))
	return h


func get_job_slots() -> Dictionary:
	var slots: Dictionary = {}
	if ProjectPaths == null:
		push_warning("Colony.get_job_slots: ProjectPaths is null; cannot load district/building defs.")
		return slots
	var d_data: Array = _load_district_defs()
	if d_data.is_empty():
		push_warning("Colony.get_job_slots: district defs empty (check path: %s)." % ProjectPaths.DATA_DISTRICTS)
	var b_data: Array = _load_building_defs()
	if b_data.is_empty():
		push_warning("Colony.get_job_slots: building defs empty (check path: %s)." % ProjectPaths.DATA_BUILDINGS)
	_ensure_city_specializations_synced()
	for d in d_data:
		var id_str: String = d.get("id", "")
		var cnt: int = district_counts.get(id_str, 0)
		if id_str == "city":
			# City districts add jobs only from the 3 planet-wide specializations
			var spec_data: Array = _load_city_specialization_defs()
			for s in city_specializations:
				if (s is String) and (s as String).length() > 0:
					for spec_def in spec_data:
						if spec_def.get("id", "") == s:
							var jobs_dict: Dictionary = spec_def.get("jobs", {})
							for j in jobs_dict:
								slots[j] = slots.get(j, 0) + int(jobs_dict[j])
							break
		else:
			var jobs_dict: Dictionary = d.get("jobs", {})
			for j in jobs_dict:
				slots[j] = slots.get(j, 0) + cnt * int(jobs_dict[j])
	for b in buildings:
		for def in b_data:
			if def.get("id", "") != b:
				continue
			var jobs_dict: Dictionary = def.get("jobs", {})
			for j in jobs_dict:
				slots[j] = slots.get(j, 0) + int(jobs_dict[j])
			break
	for spec_list in city_specialization_buildings:
		if spec_list is Array:
			for b in spec_list:
				var bid: String = b if b is String else str(b)
				for def in b_data:
					if def.get("id", "") != bid:
						continue
					var jobs_dict: Dictionary = def.get("jobs", {})
					for j in jobs_dict:
						slots[j] = slots.get(j, 0) + int(jobs_dict[j])
					break
	for b in orbital_buildings:
		for def in b_data:
			if def.get("id", "") != b:
				continue
			var jobs_dict: Dictionary = def.get("jobs", {})
			for j in jobs_dict:
				slots[j] = slots.get(j, 0) + int(jobs_dict[j])
			break
	return slots


## Fill jobs in priority order (ruler, enforcer, then specialists, then workers). Returns dict job_id -> filled count.
func assign_pops_to_jobs() -> Dictionary:
	var slots: Dictionary = get_job_slots()
	# Fill workers first so early colonies produce resources, then specialists, then ruler
	var order: Array[String] = ["technician", "miner", "farmer", "clerk", "researcher", "metallurgist", "artisan", "chemist", "acolyte", "soldier", "ruler", "enforcer"]
	var filled: Dictionary = {}
	var remaining: int = pop_count
	for job_id in order:
		var cap: int = slots.get(job_id, 0)
		var assign: int = mini(remaining, cap)
		if assign > 0:
			filled[job_id] = assign
			remaining -= assign
		if remaining <= 0:
			break
	return filled


## Produce resources from filled jobs; return dict ResourceType (int) -> delta. Includes civilian contribution.
## District amplifier buildings add +20% output for the matching job type (technician/miner/farmer).
func produce(filled_jobs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var energy_d: int = district_counts.get("energy", 0)
	var mining_d: int = district_counts.get("mining", 0)
	var farming_d: int = district_counts.get("farming", 0)
	var energy_amp: float = 1.0 + DISTRICT_AMPLIFIER_MULTIPLIER * district_amplifier_buildings.get("energy", []).size() / maxf(1.0, float(energy_d))
	var mining_amp: float = 1.0 + DISTRICT_AMPLIFIER_MULTIPLIER * district_amplifier_buildings.get("mining", []).size() / maxf(1.0, float(mining_d))
	var farming_amp: float = 1.0 + DISTRICT_AMPLIFIER_MULTIPLIER * district_amplifier_buildings.get("farming", []).size() / maxf(1.0, float(farming_d))
	for job_id in filled_jobs:
		var cnt: int = filled_jobs[job_id]
		var prod: Variant = _get_job_production_dict(job_id)
		if prod is Dictionary:
			var p: Dictionary = prod
			if p.get("resource", -1) >= 0 and p.get("amount", 0) > 0:
				var r: int = p.resource
				var amount: float = cnt * p.amount
				if job_id == "technician":
					amount *= energy_amp
				elif job_id == "miner":
					amount *= mining_amp
				elif job_id == "farmer":
					amount *= farming_amp
				out[r] = out.get(r, 0.0) + amount
			if p.has("upkeep"):
				for up_res in p.upkeep:
					out[up_res] = out.get(up_res, 0.0) - cnt * p.upkeep[up_res]
	# Civilians (pops not in jobs) still contribute a small amount of energy
	var employed: int = 0
	for _job_id in filled_jobs:
		employed += filled_jobs[_job_id]
	var civilians: int = maxi(0, pop_count - employed)
	if civilians > 0:
		var r: int = 0  # Energy
		out[r] = out.get(r, 0.0) + civilians * CIVILIAN_ENERGY_PER_POP
	return out


func get_research_output(filled_jobs: Dictionary) -> float:
	var total: float = 0.0
	var cnt: int = filled_jobs.get("researcher", 0)
	var prod: Dictionary = _get_job_production_dict("researcher")
	if prod.get("amount", 0) > 0:
		total = cnt * prod.amount
	return total


func tick(planet: Planet) -> void:
	var _filled: Dictionary = assign_pops_to_jobs()
	var max_pop: int = get_max_population(planet)
	if pop_count >= max_pop:
		growth_progress = 0.0
		return
	var growth_rate: float = GROWTH_PER_MONTH_BASE * (planet.habitability if planet != null else 0.5)
	growth_progress += growth_rate
	if growth_progress >= GROWTH_THRESHOLD:
		pop_count = mini(pop_count + 1, max_pop)
		growth_progress = 0.0


## Convert JSON cost {"0": 100, "1": 50} to Dict keyed by GameResources.ResourceType for can_afford/pay.
func _cost_dict_from_json(cost_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cost_json:
		var rt: int = int(key)
		if rt >= 0 and rt < GameResources.ResourceType.LAST:
			out[rt as GameResources.ResourceType] = float(cost_json[key])
	return out


func _ensure_city_specializations_synced() -> void:
	# Ensure city_specialization_buildings has 3 slots
	while city_specialization_buildings.size() < CITY_SPECIALIZATION_SLOTS_TOTAL:
		city_specialization_buildings.append([])
	# Migrate old format: buildings beyond base 9 move into spec slots by position (only if spec lists empty)
	var spec_buildings_empty: bool = true
	for lst in city_specialization_buildings:
		if lst is Array and (lst as Array).size() > 0:
			spec_buildings_empty = false
			break
	if spec_buildings_empty and buildings.size() > BASE_BUILDING_SLOTS:
		var extra: Array = []
		for i in range(BASE_BUILDING_SLOTS, buildings.size()):
			extra.append(buildings[i])
		for i in range(extra.size()):
			var spec_idx: int = floori(i / float(BUILDING_SLOTS_PER_CITY_SPECIALIZATION))
			if spec_idx < city_specialization_buildings.size():
				var list: Array = city_specialization_buildings[spec_idx]
				if list.size() < BUILDING_SLOTS_PER_CITY_SPECIALIZATION:
					list.append(extra[i])
		buildings.resize(BASE_BUILDING_SLOTS)
	# Migrate old format (array of arrays) to planet-wide 3 slots
	var flat: Array = []
	for v in city_specializations:
		if v is String and (v as String).length() > 0:
			flat.append(v)
		elif v is Array:
			for s in v:
				if (s is String) and (s as String).length() > 0:
					flat.append(s)
	city_specializations.clear()
	for i in range(CITY_SPECIALIZATION_SLOTS_TOTAL):
		city_specializations.append(flat[i] if i < flat.size() else "")


func add_district(district_id: String, empire: Empire, planet: Planet) -> bool:
	if empire == null or planet == null:
		return false
	var d_data: Array = _load_district_defs()
	var def: Dictionary = {}
	for d in d_data:
		if d.get("id", "") == district_id:
			def = d
			break
	if def.is_empty():
		return false
	if get_total_districts() >= get_max_districts(planet):
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	district_counts[district_id] = district_counts.get(district_id, 0) + 1
	return true


func add_building(building_id: String, empire: Empire) -> bool:
	if building_id == "capital" or empire == null:
		return false
	var b_data: Array = _load_building_defs()
	var def: Dictionary = {}
	for b in b_data:
		if b.get("id", "") == building_id:
			def = b
			break
	if def.is_empty():
		return false
	# Orbital buildings use orbital slots; must use add_orbital_building().
	if def.get("slot_type", "planetary") == "orbital":
		return false
	# Only one planetary authority per colony (already present at start on homeworld)
	if building_id == "planetary_authority" and buildings.has("planetary_authority"):
		return false
	# Base slots only (spec slots use add_city_specialization_building)
	if buildings.size() >= BASE_BUILDING_SLOTS:
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	buildings.append(building_id)
	return true


## Add a building into a city specialization's slot (only allowed_buildings for that spec).
func add_city_specialization_building(spec_index: int, building_id: String, empire: Empire) -> bool:
	if empire == null or building_id.is_empty():
		return false
	_ensure_city_specializations_synced()
	if spec_index < 0 or spec_index >= CITY_SPECIALIZATION_SLOTS_TOTAL:
		return false
	var spec_id: String = city_specializations[spec_index] as String
	if spec_id.is_empty():
		return false
	var list: Array = city_specialization_buildings[spec_index]
	if list.size() >= BUILDING_SLOTS_PER_CITY_SPECIALIZATION:
		return false
	var s_data: Array = _load_city_specialization_defs()
	var spec_def: Dictionary = {}
	for s in s_data:
		if s.get("id", "") == spec_id:
			spec_def = s
			break
	if spec_def.is_empty():
		return false
	var allowed: Array = spec_def.get("allowed_buildings", [])
	if not building_id in allowed:
		return false
	var b_data: Array = _load_building_defs()
	var def: Dictionary = {}
	for b in b_data:
		if b.get("id", "") == building_id:
			def = b
			break
	if def.is_empty() or def.get("slot_type", "planetary") != "planetary":
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	list.append(building_id)
	return true


func add_orbital_building(building_id: String, empire: Empire) -> bool:
	if empire == null or orbital_buildings.size() >= get_orbital_slots():
		return false
	var b_data: Array = _load_building_defs()
	var def: Dictionary = {}
	for b in b_data:
		if b.get("id", "") == building_id:
			def = b
			break
	if def.is_empty() or def.get("slot_type", "planetary") != "orbital":
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	orbital_buildings.append(building_id)
	return true


## Specialize city (planet-wide): fill first empty of the 3 slots (adds building slots and jobs).
func add_city_specialization(_slot_index: int, spec_id: String, empire: Empire) -> bool:
	if empire == null or spec_id.is_empty():
		return false
	_ensure_city_specializations_synced()
	# slot_index ignored for compatibility; we fill first empty
	var idx: int = -1
	for i in range(city_specializations.size()):
		if (city_specializations[i] as String).length() == 0:
			idx = i
			break
	if idx < 0:
		return false
	var s_data: Array = _load_city_specialization_defs()
	var def: Dictionary = {}
	for s in s_data:
		if s.get("id", "") == spec_id:
			def = s
			break
	if def.is_empty():
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	city_specializations[idx] = spec_id
	return true


## Add a building that amplifies output of a resource district type (energy, mining, farming).
func add_district_amplifier_building(district_type: String, building_id: String, empire: Empire) -> bool:
	if empire == null or district_type.is_empty() or building_id.is_empty():
		return false
	if not district_amplifier_buildings.has(district_type):
		return false
	var list: Array = district_amplifier_buildings[district_type]
	var max_slots: int = get_district_amplifier_slots(district_type)
	if list.size() >= max_slots:
		return false
	var b_data: Array = _load_building_defs()
	var def: Dictionary = {}
	for b in b_data:
		if b.get("id", "") == building_id and b.get("district_type", "") == district_type:
			def = b
			break
	if def.is_empty():
		return false
	var cost_json: Dictionary = def.get("cost", {})
	var cost: Dictionary = _cost_dict_from_json(cost_json)
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	list.append(building_id)
	return true


## Amplifier slots come from specializing that resource type (4 slots), not from building districts.
func get_district_amplifier_slots(district_type: String) -> int:
	if district_amplifier_specialized.get(district_type, false):
		return DISTRICT_AMPLIFIER_SLOTS_PER_SPECIALIZATION
	return 0


## Specialize a resource district type to unlock 4 amplifier building slots. Districts of that type only add jobs.
func add_resource_district_specialization(district_type: String, empire: Empire) -> bool:
	if empire == null or not district_amplifier_specialized.has(district_type):
		return false
	if district_amplifier_specialized[district_type]:
		return false
	var cost: Dictionary = {
		GameResources.ResourceType.ENERGY: float(RESOURCE_DISTRICT_SPECIALIZE_COST_ENERGY),
		GameResources.ResourceType.MINERALS: float(RESOURCE_DISTRICT_SPECIALIZE_COST_MINERALS)
	}
	if not empire.resources.can_afford(cost):
		return false
	empire.resources.pay(cost)
	district_amplifier_specialized[district_type] = true
	return true


## Returns jobs dict from a JobSlotsController on the scene node (or any descendant) if present and non-empty.
static func _get_jobs_from_scene_node(node: Node) -> Dictionary:
	if node is JobSlotsController:
		var jobs: Dictionary = (node as JobSlotsController).jobs
		return jobs.duplicate() if not jobs.is_empty() else {}
	for child in node.get_children():
		var found: Dictionary = _get_jobs_from_scene_node(child)
		if not found.is_empty():
			return found
	return {}


func _load_district_defs() -> Array:
	if ProjectPaths != null:
		var scene_dir: String = ProjectPaths.SCENES_PLANET_DISTRICTS_DIR
		var dir: DirAccess = DirAccess.open(scene_dir)
		if dir != null:
			var out: Array = []
			dir.list_dir_begin()
			var f: String = dir.get_next()
			while f != "":
				if not dir.current_is_dir() and f.ends_with(".tscn"):
					var scene: PackedScene = load(scene_dir + f) as PackedScene
					if scene != null:
						var node: Node = scene.instantiate()
						if "definition" in node and node.definition != null and node.definition is DistrictDefinitionResource:
							var def_dict: Dictionary = (node.definition as DistrictDefinitionResource).to_dict()
							var scene_jobs: Dictionary = _get_jobs_from_scene_node(node)
							if not scene_jobs.is_empty():
								def_dict["jobs"] = scene_jobs
							out.append(def_dict)
						node.queue_free()
				f = dir.get_next()
			dir.list_dir_end()
			if not out.is_empty():
				return out
		var data_dir: String = ProjectPaths.DATA_PLANET_DISTRICTS_DIR
		dir = DirAccess.open(data_dir)
		if dir != null:
			var out: Array = []
			dir.list_dir_begin()
			var f: String = dir.get_next()
			while f != "":
				if not dir.current_is_dir() and f.ends_with(".tres"):
					var res: Resource = load(data_dir + f) as Resource
					if res is DistrictDefinitionResource:
						out.append((res as DistrictDefinitionResource).to_dict())
				f = dir.get_next()
			dir.list_dir_end()
			if not out.is_empty():
				return out
	var path: String = ProjectPaths.DATA_DISTRICTS if ProjectPaths != null else "res://data/districts.json"
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return []
	return json.data if json.data is Array else []


## Static loader so planet view, space station, etc. use the same source (scenes + JSON orbital).
static func get_all_building_defs() -> Array:
	var out: Array = []
	if ProjectPaths != null:
		var scene_dir: String = ProjectPaths.SCENES_PLANET_BUILDINGS_DIR
		var dir: DirAccess = DirAccess.open(scene_dir)
		if dir != null:
			dir.list_dir_begin()
			var f: String = dir.get_next()
			while f != "":
				if not dir.current_is_dir() and f.ends_with(".tscn"):
					var scene: PackedScene = load(scene_dir + f) as PackedScene
					if scene != null:
						var node: Node = scene.instantiate()
						if "definition" in node and node.definition != null and node.definition is PlanetBuildingDefinitionResource:
							var d: Dictionary = (node.definition as PlanetBuildingDefinitionResource).to_dict()
							var scene_jobs: Dictionary = _get_jobs_from_scene_node(node)
							if not scene_jobs.is_empty():
								d["jobs"] = scene_jobs
							out.append(d)
						node.queue_free()
				f = dir.get_next()
			dir.list_dir_end()
		if out.is_empty():
			var data_dir: String = ProjectPaths.DATA_PLANET_BUILDINGS_DIR
			dir = DirAccess.open(data_dir)
			if dir != null:
				dir.list_dir_begin()
				var f: String = dir.get_next()
				while f != "":
					if not dir.current_is_dir() and f.ends_with(".tres"):
						var res: Resource = load(data_dir + f) as Resource
						if res is PlanetBuildingDefinitionResource:
							out.append((res as PlanetBuildingDefinitionResource).to_dict())
					f = dir.get_next()
				dir.list_dir_end()
	var json_path: String = ProjectPaths.DATA_BUILDINGS if ProjectPaths != null else "res://data/buildings.json"
	if FileAccess.file_exists(json_path):
		var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				for def in json.data:
					if def.get("slot_type", "planetary") == "orbital":
						out.append(def)
			file.close()
	return out


func _load_building_defs() -> Array:
	return get_all_building_defs()


func _load_city_specialization_defs() -> Array:
	var path: String = ProjectPaths.DATA_CITY_SPECIALIZATIONS
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json: JSON = JSON.new()
	var err: Error = json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return []
	return json.data if json.data is Array else []
