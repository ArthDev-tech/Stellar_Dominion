@tool
class_name BuildingBase
extends Node
## Base script for all building scenes. Inherited scenes override exported values.

# ── Identity ─────────────────────────────────────────────────────────────────
@export_group("Identity")
@export var building_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: BuildingCategory.Category = BuildingCategory.Category.EXTRACTION
@export var icon_texture: Texture2D = null

# ── Placement Rules ───────────────────────────────────────────────────────────
@export_group("Placement Rules")
@export_multiline var placement_condition: String = ""
@export var is_empire_unique: bool = false
@export var is_planet_unique: bool = false
@export var requires_orbital_slot: bool = false
@export var requires_deposit: String = ""

# ── Tier Definitions ──────────────────────────────────────────────────────────
@export_group("Tiers")
@export var tier_configs: Array[BuildingTierConfig] = []

# ── Cascade Info ──────────────────────────────────────────────────────────────
@export_group("Cascade")
@export_multiline var cascade_description: String = ""
@export_multiline var planetary_synergies: String = ""

# ── Balancing Multipliers ──────────────────────────────────────────────────────
@export_group("Balancing Overrides")
@export var global_output_multiplier: float = 1.0
@export var global_upkeep_multiplier: float = 1.0
@export var global_build_time_multiplier: float = 1.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if building_id.is_empty():
		warnings.append("building_id is empty — set this to the snake_case building name")
	if display_name.is_empty():
		warnings.append("display_name is empty")
	if tier_configs.is_empty():
		warnings.append("No tier configs defined — add at least one BuildingTierConfig")
	for i in tier_configs.size():
		var tc = tier_configs[i]
		if tc == null:
			warnings.append("Tier slot %d is null" % i)
			continue
		if tc.job_slots.is_empty() and tc.passive_outputs.is_empty():
			warnings.append("Tier %d has no job slots and no passive outputs" % (i + 1))
	return warnings


func get_tier_config(tier_level: int) -> BuildingTierConfig:
	for tc in tier_configs:
		if tc != null and tc.tier_level == tier_level:
			return tc
	return null


func max_tier() -> int:
	var max_t: int = 0
	for tc in tier_configs:
		if tc != null and tc.tier_level > max_t:
			max_t = tc.tier_level
	return max_t


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var label: Label = get_node_or_null("EditorPreviewLabel") as Label
	if label == null:
		return
	if tier_configs.is_empty():
		label.text = "[%s] — No tiers defined" % display_name
		return
	var lines: PackedStringArray = []
	lines.append("[%s]  id: %s" % [display_name, building_id])
	lines.append("Tiers: %d  |  Empire unique: %s  |  Planet unique: %s" % [
		tier_configs.size(), str(is_empire_unique), str(is_planet_unique)
	])
	for tc in tier_configs:
		if tc == null:
			continue
		var slot_count: int = tc.job_slots.size()
		var required: int = 0
		for s in tc.job_slots:
			if s != null and s.is_required:
				required += 1
		lines.append("  T%d %s — %d Alloys  %d mo  |  %d slots (%d req)  upkeep: %s" % [
			tc.tier_level, tc.tier_name, tc.alloy_cost,
			tc.build_time_months, slot_count, required,
			str(tc.upkeep)
		])
	label.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_POSTINITIALIZE:
		_update_editor_preview()


func _set(property: StringName, value: Variant) -> bool:
	if Engine.is_editor_hint():
		call_deferred("_update_editor_preview")
		call_deferred("update_configuration_warnings")
	return false
