class_name CouncilState
extends RefCounted
## Runtime: current council — who is in which position, active agenda.

var positions: Dictionary = {}  # position_id -> LeaderInstance (or null)
var active_agenda: CouncilAgenda = null
var agenda_progress: float = 0.0
var agenda_active_months_remaining: int = 0
var agenda_cooldown_remaining: Dictionary = {}  # agenda_id -> months left
