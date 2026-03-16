class_name PopAssignment
extends RefCounted
## Runtime: one per filled job slot. Lives inside BuildingInstance.

var pop_id: int = -1
var job_slot: JobSlotData = null
var building_instance_id: int = -1
var planet_id: int = -1
var months_assigned: int = 0

func is_filled() -> bool:
	return pop_id != -1

func get_monthly_output(building_multiplier: float = 1.0) -> Dictionary:
	if not is_filled() or job_slot == null:
		return {}
	var result: Dictionary = {}
	for key in job_slot.outputs:
		result[key] = job_slot.outputs[key] * building_multiplier
	return result

func get_monthly_inputs_consumed(efficiency: float = 1.0) -> Dictionary:
	if not is_filled() or job_slot == null:
		return {}
	var result: Dictionary = {}
	for key in job_slot.inputs_consumed:
		result[key] = job_slot.inputs_consumed[key] * efficiency
	return result
