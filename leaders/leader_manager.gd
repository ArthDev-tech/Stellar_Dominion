extends Node
## Leader recruitment pool, XP, death, assignment. All balancing via @export.
## Register as autoload: LeaderManager. Keeps compatibility with empire.leaders and Leader type.

# Leader capacity
@export_group("Leader Capacity")
@export var base_leader_capacity: int = 6
@export var capacity_xp_penalty_per_over: float = 0.10

# XP thresholds: xp_to_next_level = xp_base * (level ^ xp_level_exponent)
@export_group("XP Thresholds")
@export var xp_base: float = 100.0
@export var xp_level_exponent: float = 1.4

# Recruitment pool
@export_group("Recruitment")
@export var pool_refresh_years: int = 5
@export var pool_size_per_class: int = 2
@export var recruitment_cost_unity_base: int = 50
@export var recruitment_cost_unity_per_level: int = 25

# Lifespan
@export_group("Leader Lifespan")
@export var base_lifespan_years: int = 80
@export var lifespan_variance_years: int = 10
@export var death_probability_per_month_base: float = 0.002
@export var immortal_accident_probability_per_year: float = 0.05

# Upkeep
@export_group("Upkeep")
@export var unity_upkeep_per_level: float = 2.0

var _next_leader_id: int = 1
var _instances_by_empire: Dictionary = {}  # empire_id -> Array[LeaderInstance]
var _traits_json: Array = []  # legacy DATA_LEADER_TRAITS
var _trait_resources: Dictionary = {}  # trait_id -> LeaderTrait (loaded .tres)


func _ready() -> void:
	_load_legacy_traits()
	_load_trait_resources()


func _load_legacy_traits() -> void:
	var path: String = ProjectPaths.DATA_LEADER_TRAITS if ProjectPaths != null else "res://data/leader_traits.json"
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	_traits_json = json.data if json.data is Array else []


func _load_trait_resources() -> void:
	# TODO: scan res://leaders/traits/ for .tres and load into _trait_resources
	pass


func _ensure_empire_roster(empire_id: int) -> void:
	if not _instances_by_empire.has(empire_id):
		_instances_by_empire[empire_id] = []


func calculate_xp_threshold(level: int) -> float:
	return xp_base * pow(float(level), xp_level_exponent)


func get_leader_instances(empire: Empire) -> Array:
	if empire == null:
		return []
	_ensure_empire_roster(empire.id)
	return _instances_by_empire[empire.id]


func recruit_leader(empire: Empire, leader_type: int) -> Leader:
	# Compatibility: create LeaderInstance and legacy Leader; add Leader to empire.leaders
	if empire == null:
		return null
	_ensure_empire_roster(empire.id)
	var leader_class: int = _map_leader_type_to_class(leader_type)
	var inst: LeaderInstance = _create_leader_instance(empire, leader_class)
	inst.leader_id = _next_leader_id
	_next_leader_id += 1
	inst.xp_to_next_level = calculate_xp_threshold(1)
	inst.guaranteed_lifespan_months = (base_lifespan_years + randi_range(-lifespan_variance_years, lifespan_variance_years)) * 12
	_instances_by_empire[empire.id].append(inst)
	var name_key: String = inst.get_display_name()
	var l: Leader = Leader.new(inst.leader_id, empire.id, leader_type, name_key)
	l.level = inst.level
	empire.leaders.append(l)
	if EventBus != null and EventBus.has_signal("leader_recruited"):
		EventBus.emit_signal("leader_recruited", inst)
	return l


func _map_leader_type_to_class(leader_type: int) -> int:
	# Leader.LeaderType: RULER=0, GOVERNOR=1, SCIENTIST=2, ADMIRAL=3, GENERAL=4
	# LeaderClass.Class: COMMANDER=0, ADMINISTRATOR=1, SCIENTIST=2, STRATEGIST=3
	match leader_type:
		0: return LeaderClass.Class.ADMINISTRATOR  # Ruler -> Administrator
		1: return LeaderClass.Class.ADMINISTRATOR
		2: return LeaderClass.Class.SCIENTIST
		3: return LeaderClass.Class.COMMANDER
		4: return LeaderClass.Class.COMMANDER
		_: return LeaderClass.Class.SCIENTIST


func _create_leader_instance(empire: Empire, leader_class: int) -> LeaderInstance:
	var inst := LeaderInstance.new()
	inst.leader_class = leader_class
	var first_names: Array = ["Val", "Sera", "Kor", "Mira", "Dax", "Jyn", "Vex", "Nova"]
	var last_names: Array = ["Stark", "Vance", "Rho", "Chen", "Ortega", "Webb", "Kade", "Nex"]
	inst.first_name = first_names[randi() % first_names.size()]
	inst.last_name = last_names[randi() % last_names.size()]
	return inst


func get_leader(empire_id: int, leader_id: int) -> Leader:
	var emp: Empire = EmpireManager.get_empire(empire_id) if EmpireManager != null else null
	if emp == null:
		return null
	for l in emp.leaders:
		if l.id == leader_id:
			return l
	return null


func get_leader_instance(empire: Empire, leader_id: int) -> LeaderInstance:
	if empire == null:
		return null
	for inst in get_leader_instances(empire):
		if inst.leader_id == leader_id:
			return inst
	return null


func process_monthly_tick(empire: Empire) -> void:
	if empire == null:
		return
	for inst in get_leader_instances(empire):
		if inst == null:
			continue
		inst.advance_month()
		# XP from assignment (stub: small base XP when assigned)
		if inst.assignment != null and inst.assignment.type != LeaderAssignment.Type.IDLE:
			inst.current_xp += 2.0
		else:
			inst.current_xp += 0.5
		# Level-up check
		while inst.current_xp >= inst.xp_to_next_level and inst.level < 10:
			inst.current_xp -= inst.xp_to_next_level
			inst.level += 1
			inst.xp_to_next_level = calculate_xp_threshold(inst.level)
			if EventBus != null and EventBus.has_signal("leader_levelled_up"):
				EventBus.emit_signal("leader_levelled_up", inst, inst.level)
		# Death check
		if inst.death_check_active and not inst.is_immortal:
			if randf() < death_probability_per_month_base:
				if EventBus != null and EventBus.has_signal("leader_died"):
					EventBus.emit_signal("leader_died", inst)
				_instances_by_empire[empire.id].erase(inst)
				for i in empire.leaders.size():
					if (empire.leaders[i] as Leader).id == inst.leader_id:
						empire.leaders.remove_at(i)
						break
				return


func get_empire_field_modifiers(empire: Empire) -> Dictionary:
	var result: Dictionary = {}
	for inst in get_leader_instances(empire):
		if inst == null or inst.assignment == null:
			continue
		var mods: Dictionary = inst.get_field_modifiers()
		for key in mods:
			result[key] = result.get(key, 0.0) + mods[key]
	return result


func assign_scientist_to_research(empire: Empire, leader: Leader) -> void:
	if leader.leader_type != Leader.LeaderType.SCIENTIST:
		return
	for l in empire.leaders:
		if l is Leader:
			(l as Leader).assigned_to_research = (l.id == leader.id)
	var inst: LeaderInstance = get_leader_instance(empire, leader.id)
	if inst != null:
		if inst.assignment == null:
			inst.assignment = LeaderAssignment.new()
		inst.assignment.type = LeaderAssignment.Type.COUNCIL
		inst.assignment.council_position_id = "head_of_research"


func assign_governor_to_planet(empire: Empire, leader: Leader, system_id: int, planet_index: int) -> void:
	if leader.leader_type != Leader.LeaderType.GOVERNOR:
		return
	leader.assigned_planet_id = system_id * 1000 + planet_index
	leader.assigned_to_research = false
	var inst: LeaderInstance = get_leader_instance(empire, leader.id)
	if inst != null:
		if inst.assignment == null:
			inst.assignment = LeaderAssignment.new()
		inst.assignment.type = LeaderAssignment.Type.PLANET
		inst.assignment.target_id = system_id * 1000 + planet_index


func assign_admiral_to_fleet(empire: Empire, leader: Leader, fleet_id: int) -> void:
	if leader.leader_type != Leader.LeaderType.ADMIRAL:
		return
	leader.assigned_fleet_id = fleet_id
	var inst: LeaderInstance = get_leader_instance(empire, leader.id)
	if inst != null:
		if inst.assignment == null:
			inst.assignment = LeaderAssignment.new()
		inst.assignment.type = LeaderAssignment.Type.FLEET
		inst.assignment.target_id = fleet_id


func get_traits_for_type(leader_type: int) -> Array:
	var type_name: String = Leader.get_type_name(leader_type).to_lower()
	var out: Array = []
	for t in _traits_json:
		var types: Array = t.get("leader_types", [])
		if type_name in types:
			out.append(t)
	return out


func get_trait_def(trait_id: String) -> Dictionary:
	if _trait_resources.has(trait_id):
		return {}  # Resource, not dict — legacy UI may expect dict
	for t in _traits_json:
		if t.get("id", "") == trait_id:
			return t
	return {}
