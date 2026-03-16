extends Node
## Auto-assigns idle pops to empty job slots by priority. Register as autoload: JobAssignmentManager.
## Works with planets that have BuildingInstance arrays (future Colony integration).

# Priority order for auto-assignment (highest first). Lower index = higher priority.
const SLOT_PRIORITY_ORDER: Array = [
	JobType.Type.REACTOR_OPERATOR, JobType.Type.MINER, JobType.Type.FARMER,
	JobType.Type.METALLURGIST, JobType.Type.FUEL_ENGINEER, JobType.Type.MANUFACTURER,
	JobType.Type.CHEMIST, JobType.Type.FABRICATOR, JobType.Type.PHYSICIST,
	JobType.Type.SOCIOLOGIST, JobType.Type.XENOLOGIST, JobType.Type.ADMINISTRATOR,
	JobType.Type.CULTURAL_WORKER, JobType.Type.SOLDIER, JobType.Type.GARRISON,
	JobType.Type.SHIPWRIGHT, JobType.Type.CRYSTAL_HANDLER, JobType.Type.NANITE_WARDEN,
	JobType.Type.VOID_ENGINEER, JobType.Type.GAS_TECHNICIAN,
]


func _slot_priority(a: PopAssignment) -> int:
	if a == null or a.job_slot == null:
		return -1
	var t: JobType.Type = a.job_slot.job_type
	for i in SLOT_PRIORITY_ORDER.size():
		if SLOT_PRIORITY_ORDER[i] == t:
			return 1000 - i
	return 0


func _pop_satisfies_restriction(_pop_id: int, job_slot: JobSlotData) -> bool:
	if job_slot == null or job_slot.pop_type_restriction.is_empty():
		return true
	# TODO: check pop traits when pop system exists
	return true


func get_unfilled_required_slots(planet: Variant) -> Array:
	var out: Array = []
	# Planet must have a method or property to get building instances
	if planet == null:
		return out
	if planet.get("building_instances") != null:
		for bi in planet.building_instances:
			if bi == null or not bi.is_online:
				continue
			for a in bi.job_assignments:
				if a != null and a.job_slot != null and a.job_slot.is_required and not a.is_filled():
					out.append(a)
	return out


func _get_unfilled_bonus_slots(planet: Variant) -> Array:
	var out: Array = []
	if planet == null or planet.get("building_instances") == null:
		return out
	for bi in planet.building_instances:
		if bi == null or not bi.is_online:
			continue
		for a in bi.job_assignments:
			if a != null and a.job_slot != null and not a.job_slot.is_required and not a.is_filled():
				out.append(a)
	return out


func get_idle_pops(planet: Variant) -> Array:
	# TODO: when Colony has pop list with IDs, return pops not in any assignment
	# For now return empty; run_auto_assignment will still fill slots when pops are provided elsewhere
	if planet == null:
		return []
	if planet.get("pop_count") != null:
		var assigned: Dictionary = {}
		if planet.get("building_instances") != null:
			for bi in planet.building_instances:
				if bi == null:
					continue
				for a in bi.job_assignments:
					if a != null and a.is_filled():
						assigned[a.pop_id] = true
		var idle: Array = []
		for pid in range(planet.pop_count):
			if not assigned.get(pid, false):
				idle.append(pid)
		return idle
	return []


func run_auto_assignment(planet: Variant) -> void:
	if planet == null:
		return
	var unfilled: Array = get_unfilled_required_slots(planet)
	unfilled.sort_custom(func(a, b): return _slot_priority(a) > _slot_priority(b))
	var idle: Array = get_idle_pops(planet)

	for slot_assignment in unfilled:
		if idle.is_empty():
			break
		for i in idle.size():
			var pop_id: int = idle[i]
			if _pop_satisfies_restriction(pop_id, slot_assignment.job_slot):
				slot_assignment.pop_id = pop_id
				idle.remove_at(i)
				break

	var bonus_unfilled: Array = _get_unfilled_bonus_slots(planet)
	bonus_unfilled.sort_custom(func(a, b): return _slot_priority(a) > _slot_priority(b))
	for slot_assignment in bonus_unfilled:
		if idle.is_empty():
			break
		for i in idle.size():
			var pop_id: int = idle[i]
			if _pop_satisfies_restriction(pop_id, slot_assignment.job_slot):
				slot_assignment.pop_id = pop_id
				idle.remove_at(i)
				break

	if EventBus != null:
		EventBus.emit_signal("job_assignment_updated", planet)


func manual_assign(pop_id: int, assignment: PopAssignment) -> bool:
	if assignment == null:
		return false
	assignment.pop_id = pop_id
	return true


func unassign_pop(pop_id: int, planet: Variant) -> void:
	if planet == null or planet.get("building_instances") == null:
		return
	for bi in planet.building_instances:
		if bi == null:
			continue
		for a in bi.job_assignments:
			if a != null and a.pop_id == pop_id:
				a.pop_id = -1


func on_building_offline(planet: Variant, building: Variant) -> void:
	if building == null or building.get("job_assignments") == null:
		return
	for a in building.job_assignments:
		if a != null:
			a.pop_id = -1
	if EventBus != null:
		EventBus.emit_signal("job_assignment_updated", planet)
