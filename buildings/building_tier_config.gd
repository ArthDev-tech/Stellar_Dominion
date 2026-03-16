class_name BuildingTierConfig
extends Resource
## One tier's config: construction cost, upkeep, job slots. Replaces/extends BuildingTier from building prompt.

# ── Tier Identity ─────────────────────────────────────────────────────────────
@export_group("Tier Identity")
@export var tier_level: int = 1
@export var tier_name: String = ""
@export var unlock_tech: String = ""

# ── Construction ──────────────────────────────────────────────────────────────
@export_group("Construction")
@export var alloy_cost: int = 60
@export var build_time_months: int = 18

# ── Upkeep (paid monthly regardless of job fill) ──────────────────────────────
@export_group("Upkeep")
@export var upkeep: Dictionary = {}

# ── Job Slots ─────────────────────────────────────────────────────────────────
@export_group("Job Slots")
@export var job_slots: Array[JobSlotData] = []

# ── Passive Building Output ──────────────────────────────────────────────────
@export_group("Passive Output")
@export var passive_outputs: Dictionary = {}
@export var passive_inputs_consumed: Dictionary = {}

# ── Special Flags ─────────────────────────────────────────────────────────────
@export_group("Special Flags")
@export var requires_matrioshka_brain: bool = false
@export var cognite_gate_months: int = 0
@export_multiline var special_notes: String = ""
