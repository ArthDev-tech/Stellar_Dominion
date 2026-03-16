class_name JobSlotData
extends Resource
## One job slot's static definition. Every value is editable in the Inspector when embedded in a building tier.

# ── Identity ─────────────────────────────────────────────────────────────
@export_group("Identity")
@export var job_type: JobType.Type = JobType.Type.MINER
@export var slot_label: String = ""
@export var is_required: bool = true
@export var pop_type_restriction: String = ""

# ── Monthly Outputs (when this slot is filled) ────────────────────────────
@export_group("Outputs")
@export var outputs: Dictionary = {}

# ── Monthly Inputs Consumed (refinement jobs only) ───────────────────────
@export_group("Inputs Consumed")
@export var inputs_consumed: Dictionary = {}

# ── Happiness & Social Effects ────────────────────────────────────────────
@export_group("Social Effects")
@export var happiness_modifier: float = 0.0
@export var unity_per_filled_slot: float = 0.0

# ── Balancing Notes ───────────────────────────────────────────────────────
@export_group("Notes")
@export_multiline var designer_notes: String = ""
