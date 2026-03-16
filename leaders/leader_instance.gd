class_name LeaderInstance
extends RefCounted
## Runtime: a living leader with level, traits, assignment.

# ── Identity ──────────────────────────────────────────────────────────────────
var leader_id: int = -1
var leader_class: int = 0  # LeaderClass.Class
var first_name: String = ""
var last_name: String = ""
var home_planet_id: int = -1
var species_id: int = -1

# ── Progression ───────────────────────────────────────────────────────────────
var level: int = 1
var current_xp: float = 0.0
var xp_to_next_level: float = 100.0
var traits: Array = []
var pending_trait_choice: Array = []
var months_alive: int = 0
var guaranteed_lifespan_months: int = 0
var death_check_active: bool = false

# ── Assignment ────────────────────────────────────────────────────────────────
var assignment: LeaderAssignment = null

# ── Flags ─────────────────────────────────────────────────────────────────────
var is_paragon: bool = false
var is_immortal: bool = false
var is_veteran: bool = false
var has_destiny: bool = false
var pinned_to_assignment: bool = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal levelled_up(leader: Variant, new_level: int)
signal gained_trait(leader: Variant, trait_resource: Variant)
signal leader_died(leader: Variant)
signal assignment_changed(leader: Variant, new_assignment: Variant)


func get_display_name() -> String:
	return "%s %s" % [first_name, last_name]


func add_xp(amount: float) -> void:
	current_xp += amount
	# Level-up and threshold handled by LeaderManager each month


func _assignment_matches_trait(trait_res: Variant) -> bool:
	if assignment == null or trait_res == null:
		return trait_res.get("applies_always", false) if trait_res != null else false
	if trait_res.get("applies_when_governing_planet", false) and assignment.type == LeaderAssignment.Type.PLANET:
		return true
	if trait_res.get("applies_when_on_council", false) and assignment.type == LeaderAssignment.Type.COUNCIL:
		return true
	return trait_res.get("applies_always", false)


func get_field_modifiers() -> Dictionary:
	var result: Dictionary = {}
	for trait_ref in traits:
		if trait_ref == null:
			continue
		if trait_ref.get("applies_always", true) or (assignment != null and _assignment_matches_trait(trait_ref)):
			var fm: Dictionary = trait_ref.get("field_modifiers", {})
			var scale: float = trait_ref.get("global_modifier_scale", 1.0)
			for key in fm:
				var val: float = fm[key] * scale
				result[key] = result.get(key, 0.0) + val
	return result


func get_council_modifiers() -> Dictionary:
	var result: Dictionary = {}
	for trait_ref in traits:
		if trait_ref == null or not trait_ref.get("applies_when_on_council", false):
			continue
		var cm: Dictionary = trait_ref.get("council_modifiers", {})
		var scale: float = float(level) if trait_ref.get("council_effect_scale_with_level", true) else 1.0
		var gscale: float = trait_ref.get("global_modifier_scale", 1.0)
		for key in cm:
			var val: float = cm[key] * scale * gscale
			result[key] = result.get(key, 0.0) + val
	return result


func get_cascade_prevention() -> Dictionary:
	var result: Dictionary = {}
	for trait_ref in traits:
		if trait_ref == null:
			continue
		var cp: Dictionary = trait_ref.get("cascade_prevention", {})
		for key in cp:
			result[key] = result.get(key, 0.0) + cp[key]
	return result


func advance_month() -> void:
	months_alive += 1
	if is_immortal:
		return
	if months_alive < guaranteed_lifespan_months:
		return
	death_check_active = true
