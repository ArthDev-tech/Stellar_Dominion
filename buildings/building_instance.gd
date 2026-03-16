class_name BuildingInstance
extends RefCounted
## Runtime object: a building placed on a planet. Holds tier, job assignments, online state.

var definition_id: String = ""
var current_tier: int = 1
var planet: Variant = null  ## Planet (RefCounted)
var is_online: bool = true
var offline_reason: String = ""
var months_at_current_tier: int = 0

var scene_path: String = ""
var building_scene: Node = null  ## BuildingBase (Node) when loaded
var job_assignments: Array[PopAssignment] = []

signal went_offline(building: BuildingInstance, reason: String)
signal came_online(building: BuildingInstance)


func _get_scene_tier_config() -> BuildingTierConfig:
	if building_scene == null:
		return null
	if not building_scene.has_method("get_tier_config"):
		return null
	return building_scene.get_tier_config(current_tier)


func initialise_job_slots() -> void:
	job_assignments.clear()
	var config: BuildingTierConfig = _get_scene_tier_config()
	if config == null:
		return
	for slot in config.job_slots:
		var assignment := PopAssignment.new()
		assignment.job_slot = slot
		assignment.building_instance_id = get_instance_id()
		assignment.planet_id = planet.get_instance_id() if planet != null else -1
		job_assignments.append(assignment)


func get_efficiency() -> float:
	var config: BuildingTierConfig = _get_scene_tier_config()
	if config == null:
		return 0.0
	var required_slots: Array = []
	for a in job_assignments:
		if a.job_slot != null and a.job_slot.is_required:
			required_slots.append(a)
	if required_slots.is_empty():
		return 1.0
	var filled_required: int = 0
	for a in required_slots:
		if a.is_filled():
			filled_required += 1
	return float(filled_required) / float(required_slots.size())


func get_monthly_outputs() -> Dictionary:
	if not is_online:
		return {}
	var config: BuildingTierConfig = _get_scene_tier_config()
	if config == null:
		return {}

	var multiplier: float = 1.0
	if building_scene != null and building_scene.get("global_output_multiplier") != null:
		multiplier = building_scene.global_output_multiplier

	var efficiency: float = get_efficiency()
	var result: Dictionary = {}

	# Passive outputs
	for key in config.passive_outputs:
		result[key] = config.passive_outputs[key] * multiplier

	# Required slot outputs (scaled by efficiency)
	for assignment in job_assignments:
		if assignment.job_slot == null or not assignment.job_slot.is_required:
			continue
		if assignment.is_filled():
			var slot_out: Dictionary = assignment.get_monthly_output(multiplier * efficiency)
			for key in slot_out:
				result[key] = result.get(key, 0.0) + slot_out[key]

	# Bonus slot outputs (full when filled)
	for assignment in job_assignments:
		if assignment.job_slot == null or assignment.job_slot.is_required:
			continue
		if assignment.is_filled():
			var slot_out: Dictionary = assignment.get_monthly_output(multiplier)
			for key in slot_out:
				result[key] = result.get(key, 0.0) + slot_out[key]

	return result


func get_monthly_upkeep() -> Dictionary:
	if not is_online:
		return {}
	var config: BuildingTierConfig = _get_scene_tier_config()
	if config == null:
		return {}
	var multiplier: float = 1.0
	if building_scene != null and building_scene.get("global_upkeep_multiplier") != null:
		multiplier = building_scene.global_upkeep_multiplier
	var result: Dictionary = {}
	for key in config.upkeep:
		result[key] = config.upkeep[key] * multiplier
	return result


func set_offline(reason: String) -> void:
	if is_online:
		is_online = false
		offline_reason = reason
		went_offline.emit(self, reason)


func set_online() -> void:
	if not is_online:
		is_online = true
		offline_reason = ""
		came_online.emit(self)


func advance_month() -> void:
	if is_online:
		months_at_current_tier += 1
