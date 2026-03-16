extends Node
## Tracks council assignments, agenda progress, aggregates empire modifiers. Register as autoload: CouncilManager.

@export_group("Agenda Progress")
@export var progress_per_councilor_level_per_month: float = 10.0
@export var empire_size_penalty_above: int = 100
@export var empire_size_penalty_percent_per_point: float = 0.001
@export var legitimacy_bonus_cap: float = 0.25
@export var legitimacy_penalty_cap: float = -0.50

@export_group("Council Size")
@export var base_council_size: int = 4
@export var max_council_size: int = 6

var _state_by_empire: Dictionary = {}  # empire_id -> CouncilState
var _positions: Dictionary = {}  # position_id -> CouncilPosition (loaded .tres)


func _ready() -> void:
	# TODO: load council position .tres into _positions
	pass


func _get_state(empire_id: int) -> CouncilState:
	if not _state_by_empire.has(empire_id):
		_state_by_empire[empire_id] = CouncilState.new()
	return _state_by_empire[empire_id]


func get_empire_modifiers(empire_id: int) -> Dictionary:
	var result: Dictionary = {}
	var state: CouncilState = _get_state(empire_id)
	for pos_id in state.positions:
		var leader = state.positions[pos_id]
		if leader != null:
			var mods: Dictionary = leader.get_council_modifiers()
			for key in mods:
				result[key] = result.get(key, 0.0) + mods[key]
		else:
			var pos: CouncilPosition = _positions.get(pos_id)
			if pos != null:
				for key in pos.unfilled_penalty:
					result[key] = result.get(key, 0.0) + pos.unfilled_penalty[key]
	return result


func get_cascade_prevention(empire_id: int) -> Dictionary:
	var result: Dictionary = {}
	var state: CouncilState = _get_state(empire_id)
	for pos_id in state.positions:
		var leader = state.positions[pos_id]
		if leader != null:
			var cp: Dictionary = leader.get_cascade_prevention()
			for key in cp:
				result[key] = result.get(key, 0.0) + cp[key]
	return result


func assign_leader(leader: LeaderInstance, position_id: String) -> bool:
	if leader == null:
		return false
	var empire_id: int = -1
	if EmpireManager != null:
		for e in EmpireManager.empires:
			for inst in LeaderManager.get_leader_instances(e) if LeaderManager != null else []:
				if inst == leader:
					empire_id = e.id
					break
	if empire_id < 0:
		return false
	var state: CouncilState = _get_state(empire_id)
	state.positions[position_id] = leader
	if leader.assignment == null:
		leader.assignment = LeaderAssignment.new()
	leader.assignment.type = LeaderAssignment.Type.COUNCIL
	leader.assignment.council_position_id = position_id
	if EventBus != null and EventBus.has_signal("council_position_filled"):
		EventBus.emit_signal("council_position_filled", position_id, leader)
	return true


func remove_leader(position_id: String, empire_id: int) -> void:
	var state: CouncilState = _get_state(empire_id)
	if state.positions.has(position_id):
		var leader = state.positions[position_id]
		state.positions[position_id] = null
		if leader != null and leader.assignment != null:
			leader.assignment.type = LeaderAssignment.Type.IDLE
			leader.assignment.council_position_id = ""
		if EventBus != null and EventBus.has_signal("council_position_unfilled"):
			EventBus.emit_signal("council_position_unfilled", position_id)


func set_agenda(empire_id: int, agenda: CouncilAgenda) -> bool:
	var state: CouncilState = _get_state(empire_id)
	if state.active_agenda != null:
		return false
	state.active_agenda = agenda
	state.agenda_progress = 0.0
	if EventBus != null and EventBus.has_signal("council_agenda_launched"):
		EventBus.emit_signal("council_agenda_launched", agenda)
	return true


func process_monthly_tick(empire_id: int) -> void:
	var state: CouncilState = _get_state(empire_id)
	if state.active_agenda != null:
		state.agenda_progress += progress_per_councilor_level_per_month * 4.0  # stub: 4 councilors
		if state.agenda_progress >= state.active_agenda.base_progress_cost:
			state.agenda_active_months_remaining = state.active_agenda.active_duration_months
			if EventBus != null and EventBus.has_signal("council_agenda_completed"):
				EventBus.emit_signal("council_agenda_completed", state.active_agenda)
			state.active_agenda = null
	if state.agenda_active_months_remaining > 0:
		state.agenda_active_months_remaining -= 1


func get_legitimacy(_empire_id: int) -> float:
	# Stub: no faction approval system yet
	return 0.75
