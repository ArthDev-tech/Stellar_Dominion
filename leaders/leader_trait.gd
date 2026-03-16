class_name LeaderTrait
extends Resource
## One trait's full definition. All values are Inspector-editable.

enum TraitTier {
	BACKGROUND,
	LEVEL,
	VETERAN,
	DESTINY,
	PARAGON,
	NEGATIVE,
	EVENT,
}

# ── Identity ─────────────────────────────────────────────────────────────────
@export_group("Identity")
@export var trait_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var trait_tier: TraitTier = TraitTier.BACKGROUND
@export var is_negative: bool = false
@export var eligible_classes: Array = []  # LeaderClass.Class enum values (int)

# ── Assignment Scope ──────────────────────────────────────────────────────────
@export_group("Assignment Scope")
@export var applies_when_governing_planet: bool = false
@export var applies_when_on_council: bool = false
@export var applies_always: bool = true
@export var council_effect_scale_with_level: bool = true

# ── Modifiers: Field Effects ──────────────────────────────────────────────────
@export_group("Field Effects")
@export var field_modifiers: Dictionary = {}

# ── Modifiers: Council Effects ────────────────────────────────────────────────
@export_group("Council Effects")
@export var council_modifiers: Dictionary = {}

# ── Cascade Prevention ────────────────────────────────────────────────────────
@export_group("Cascade Prevention")
@export var cascade_prevention: Dictionary = {}

# ── XP Modifiers ─────────────────────────────────────────────────────────────
@export_group("XP & Progression")
@export var xp_gain_modifier: float = 0.0
@export var lifespan_modifier_years: float = 0.0

# ── Upkeep ───────────────────────────────────────────────────────────────────
@export_group("Upkeep")
@export var unity_upkeep_modifier: float = 0.0

# ── Balancing ─────────────────────────────────────────────────────────────────
@export_group("Balancing")
@export var global_modifier_scale: float = 1.0
@export_multiline var designer_notes: String = ""
