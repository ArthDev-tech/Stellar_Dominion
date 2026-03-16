class_name CouncilAgenda
extends Resource
## One agenda definition: preparation phase, active phase, cooldown.

@export_group("Identity")
@export var agenda_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Unlock Condition")
@export var requires_tech: String = ""
@export var requires_tradition: String = ""

@export_group("Preparation Phase")
@export var preparation_modifiers: Dictionary = {}
@export var base_progress_cost: float = 7000.0

@export_group("Active Phase (after launch)")
@export var active_modifiers: Dictionary = {}
@export var active_duration_months: int = 120

@export_group("Cooldown")
@export var cooldown_months: int = 360
