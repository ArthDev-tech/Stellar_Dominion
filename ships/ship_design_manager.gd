extends Node
## Loads hulls, components, and design templates; stores custom designs per empire.
## Computes design cost, build time, and stats from hull + loadout. Access via autoload ShipDesignManager.

var _hulls: Dictionary = {}  ## hull_id -> dict
var _components: Dictionary = {}  ## component_id -> dict
var _template_designs: Dictionary = {}  ## design_id -> dict (from JSON, has hull_id, loadout, etc.)
var _custom_designs: Dictionary = {}  ## design_id -> dict (empire_id, hull_id, name_key, loadout, ship_role, auto_upgrade, auto_generate)
var _empire_design_ids: Dictionary = {}  ## empire_id -> Array[design_id]

const STAT_KEYS: Array[String] = ["hull", "armor", "shields", "evasion", "damage", "speed", "sensor_range", "power_drain", "power_produced"]

## Legacy component ids (no _t1 suffix) resolve to tier 1 for backward compatibility.
const LEGACY_COMPONENT_IDS: Dictionary = {
	"weapon_laser_s": "weapon_laser_s_t1",
	"weapon_kinetic_s": "weapon_kinetic_s_t1",
	"armor_plate_s": "armor_plate_s_t1",
	"armor_ablative_s": "armor_ablative_s_t1",
	"reactor_s": "reactor_s_t1",
	"utility_sensor_1": "utility_sensor_t1",
	"utility_computer_1": "utility_computer_t1",
}


func _ready() -> void:
	_load_hulls()
	_load_components()
	_load_design_templates()


func _load_hulls() -> void:
	_hulls.clear()
	if not FileAccess.file_exists(ProjectPaths.DATA_SHIP_HULLS):
		return
	var f: FileAccess = FileAccess.open(ProjectPaths.DATA_SHIP_HULLS, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK or json.data is not Array:
		f.close()
		return
	for h in json.data:
		var hid: String = h.get("id", "")
		if hid.is_empty():
			continue
		_hulls[hid] = h
	f.close()


func _load_components() -> void:
	_components.clear()
	if not FileAccess.file_exists(ProjectPaths.DATA_SHIP_COMPONENTS):
		return
	var f: FileAccess = FileAccess.open(ProjectPaths.DATA_SHIP_COMPONENTS, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK or json.data is not Array:
		f.close()
		return
	for c in json.data:
		var cid: String = c.get("id", "")
		if cid.is_empty():
			continue
		_components[cid] = c
	f.close()


func _load_design_templates() -> void:
	_template_designs.clear()
	if not FileAccess.file_exists(ProjectPaths.DATA_SHIP_DESIGNS):
		return
	var f: FileAccess = FileAccess.open(ProjectPaths.DATA_SHIP_DESIGNS, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK or json.data is not Array:
		f.close()
		return
	for d in json.data:
		var did: String = d.get("id", "")
		if did.is_empty():
			continue
		_template_designs[did] = d
	f.close()


func get_hull(hull_id: String) -> Dictionary:
	return _hulls.get(hull_id, {}).duplicate()


func get_component(component_id: String) -> Dictionary:
	if _components.has(component_id):
		return _components[component_id].duplicate()
	var resolved: String = LEGACY_COMPONENT_IDS.get(component_id, "")
	if not resolved.is_empty() and _components.has(resolved):
		return _components[resolved].duplicate()
	return {}


func get_all_hulls() -> Array:
	var out: Array = []
	for hid in _hulls:
		out.append(_hulls[hid].duplicate())
	return out


func get_all_components() -> Array:
	var out: Array = []
	for cid in _components:
		out.append(_components[cid].duplicate())
	return out


## Returns components for the given slot, optionally filtered by empire tech. Sorted by tier ascending.
func get_components_for_slot(slot_type: String, size: String, empire: Empire = null) -> Array:
	var out: Array = []
	for cid in _components:
		var c: Dictionary = _components[cid]
		if c.get("slot_type", "") != slot_type or c.get("size", "") != size:
			continue
		if empire != null:
			var req_tech: String = c.get("required_tech_id", "")
			if req_tech.is_empty():
				var tech_req: Variant = c.get("tech_required", null)
				req_tech = "" if tech_req == null else str(tech_req)
			if not req_tech.is_empty() and req_tech not in empire.completed_tech_ids:
				continue
		out.append(c.duplicate())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tier", 0)) < int(b.get("tier", 0))
	)
	return out


## Returns full design dict (template or custom). Includes name_key, category, hull_color, shape from template or hull; cost/build_time/stats computed.
func get_design(design_id: String) -> Dictionary:
	if _custom_designs.has(design_id):
		return _design_dict_from_custom(_custom_designs[design_id], design_id)
	if _template_designs.has(design_id):
		return _design_dict_from_template(_template_designs[design_id])
	return {}


func _design_dict_from_template(t: Dictionary) -> Dictionary:
	var hull_id: String = t.get("hull_id", "")
	var loadout: Dictionary = t.get("loadout", {})
	if hull_id.is_empty():
		hull_id = _infer_hull_from_legacy(t)
	var hull: Dictionary = get_hull(hull_id)
	var cost: Dictionary = compute_design_cost(hull_id, loadout)
	if cost.is_empty() and t.has("cost"):
		cost = _cost_dict_from_json(t.get("cost", {}))
	var build_time: int = compute_build_time_months(hull_id, loadout)
	if build_time <= 0:
		build_time = int(t.get("build_time_months", 12))
	var stats: Dictionary = compute_design_stats(hull_id, loadout)
	var out: Dictionary = {
		"id": t.get("id", ""),
		"name_key": t.get("name_key", ""),
		"category": t.get("category", "other"),
		"hull_id": hull_id,
		"hull_color": t.get("hull_color", hull.get("hull_color", [0.9, 0.85, 0.5])),
		"shape": t.get("shape", hull.get("shape", "triangle")),
		"loadout": loadout.duplicate(),
		"cost": cost,
		"build_time_months": build_time,
		"upkeep": compute_design_upkeep(hull_id, loadout),
		"is_custom": false,
	}
	for k in stats:
		out[k] = stats[k]
	return out


func _design_dict_from_custom(c: Dictionary, design_id: String) -> Dictionary:
	var hull_id: String = c.get("hull_id", "")
	var loadout: Dictionary = c.get("loadout", {})
	var hull: Dictionary = get_hull(hull_id)
	var out: Dictionary = {
		"id": design_id,
		"name_key": c.get("name_key", "Custom"),
		"category": hull.get("category", "other"),
		"hull_id": hull_id,
		"hull_color": hull.get("hull_color", [0.9, 0.85, 0.5]),
		"shape": hull.get("shape", "triangle"),
		"loadout": loadout.duplicate(),
		"cost": compute_design_cost(hull_id, loadout),
		"build_time_months": compute_build_time_months(hull_id, loadout),
		"upkeep": compute_design_upkeep(hull_id, loadout),
		"is_custom": true,
		"ship_role": c.get("ship_role", "Custom"),
		"auto_upgrade": c.get("auto_upgrade", false),
		"auto_generate": c.get("auto_generate", false),
	}
	var stats: Dictionary = compute_design_stats(hull_id, loadout)
	for k in stats:
		out[k] = stats[k]
	return out


func _infer_hull_from_legacy(t: Dictionary) -> String:
	var cat: String = t.get("category", "")
	if cat == "military":
		return "corvette"
	return "civilian_small"


func _cost_dict_from_json(cost_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cost_json:
		var rt: int = int(key)
		if rt >= 0 and rt < GameResources.ResourceType.LAST:
			out[rt as GameResources.ResourceType] = float(cost_json[key])
	return out


func _upkeep_dict_from_json(upkeep_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in upkeep_json:
		var rt: int = int(key)
		if rt >= 0 and rt < GameResources.ResourceType.LAST:
			out[rt as GameResources.ResourceType] = float(upkeep_json[key])
	return out


## Returns resource type -> amount (for cost).
func compute_design_cost(hull_id: String, loadout: Dictionary) -> Dictionary:
	var hull: Dictionary = _hulls.get(hull_id, {})
	if hull.is_empty():
		return {}
	var cost: Dictionary = _cost_dict_from_json(hull.get("cost", {}))
	for slot_id in loadout:
		var comp_id: String = loadout[slot_id]
		var comp: Dictionary = get_component(comp_id)
		if comp.is_empty():
			continue
		var comp_cost: Dictionary = _cost_dict_from_json(comp.get("cost", {}))
		for rt in comp_cost:
			cost[rt] = cost.get(rt, 0.0) + comp_cost[rt]
	return cost


## Returns resource type -> monthly upkeep.
func compute_design_upkeep(hull_id: String, loadout: Dictionary) -> Dictionary:
	var hull: Dictionary = _hulls.get(hull_id, {})
	var upkeep: Dictionary = _upkeep_dict_from_json(hull.get("upkeep", {}))
	for slot_id in loadout:
		var comp: Dictionary = get_component(loadout[slot_id])
		if comp.is_empty():
			continue
		var cu: Dictionary = _upkeep_dict_from_json(comp.get("upkeep", {}))
		for rt in cu:
			upkeep[rt] = upkeep.get(rt, 0.0) + cu[rt]
	return upkeep


func compute_build_time_months(hull_id: String, loadout: Dictionary) -> int:
	var hull: Dictionary = _hulls.get(hull_id, {})
	if hull.is_empty():
		return 12
	var total: int = int(hull.get("base_build_time_months", 12))
	for slot_id in loadout:
		var comp: Dictionary = get_component(loadout[slot_id])
		if comp.is_empty():
			continue
		total += int(comp.get("build_time_months", 0))
	return total


## Returns dict: hull, armor, shields, evasion, damage, speed, sensor_range, power (net), ship_size, naval_capacity.
func compute_design_stats(hull_id: String, loadout: Dictionary) -> Dictionary:
	var hull: Dictionary = _hulls.get(hull_id, {})
	if hull.is_empty():
		return {}
	var stats: Dictionary = {
		"hull": float(hull.get("base_hull", 0)),
		"armor": float(hull.get("base_armor", 0)),
		"shields": 0.0,
		"evasion": float(hull.get("base_evasion", 0)),
		"damage": 0.0,
		"speed": 0.0,
		"sensor_range": 0,
		"power": float(hull.get("base_power", 0)),
		"power_drain": 0.0,
		"ship_size": int(hull.get("ship_size", 1)),
		"naval_capacity": float(hull.get("naval_capacity", 1.0)),
	}
	for slot_id in loadout:
		var comp: Dictionary = get_component(loadout[slot_id])
		if comp.is_empty():
			continue
		stats["hull"] += float(comp.get("hull", 0))
		stats["armor"] += float(comp.get("armor", 0))
		stats["shields"] += float(comp.get("shields", 0))
		stats["evasion"] += float(comp.get("evasion", 0))
		stats["damage"] += float(comp.get("damage", 0))
		stats["speed"] += float(comp.get("speed", 0))
		stats["sensor_range"] += int(comp.get("sensor_range", 0))
		stats["power"] += float(comp.get("power_produced", 0))
		stats["power_drain"] += float(comp.get("power_drain", 0))
	stats["power"] = stats["power"] - stats["power_drain"]
	stats["transit_time_modifier"] = get_transit_time_modifier_from_loadout(loadout)
	return stats


## Returns transit time multiplier from design's loadout (1.0 = no change). Uses lowest modifier if multiple star_drive components.
func get_transit_time_modifier_for_design(design_id: String) -> float:
	var d: Dictionary = get_design(design_id)
	if d.is_empty():
		return 1.0
	var loadout: Dictionary = d.get("loadout", {})
	return get_transit_time_modifier_from_loadout(loadout)


func get_transit_time_modifier_from_loadout(loadout: Dictionary) -> float:
	var best: float = 1.0  # No drive = baseline
	for slot_id in loadout:
		var comp: Dictionary = get_component(loadout[slot_id])
		if comp.is_empty():
			continue
		if comp.get("category", "") != "star_drive" and comp.get("slot_type", "") != "star_drive":
			continue
		var mod: float = float(comp.get("transit_time_modifier", 1.0))
		if mod < best:
			best = mod
	return best


func get_designs_for_empire(empire_id: int) -> Array:
	var out: Array = []
	for did in _template_designs:
		out.append(get_design(did))
	var custom_ids: Array = _empire_design_ids.get(empire_id, [])
	for did in custom_ids:
		if _custom_designs.has(did):
			out.append(get_design(did))
	return out


func create_design(empire_id: int, hull_id: String, name_key: String, loadout: Dictionary, ship_role: String = "Custom", auto_upgrade: bool = false, auto_generate: bool = false) -> String:
	var design_id: String = "custom_%d_%s" % [empire_id, str(Time.get_ticks_msec())]
	_custom_designs[design_id] = {
		"empire_id": empire_id,
		"hull_id": hull_id,
		"name_key": name_key,
		"loadout": loadout.duplicate(),
		"ship_role": ship_role,
		"auto_upgrade": auto_upgrade,
		"auto_generate": auto_generate,
	}
	if not _empire_design_ids.has(empire_id):
		_empire_design_ids[empire_id] = []
	_empire_design_ids[empire_id].append(design_id)
	return design_id


func update_design(design_id: String, name_key: String = "", loadout: Dictionary = {}, ship_role: String = "", auto_upgrade: bool = false, auto_generate: bool = false) -> bool:
	if not _custom_designs.has(design_id):
		return false
	var c: Dictionary = _custom_designs[design_id]
	if name_key != "":
		c["name_key"] = name_key
	if not loadout.is_empty():
		c["loadout"] = loadout.duplicate()
	if ship_role != "":
		c["ship_role"] = ship_role
	c["auto_upgrade"] = auto_upgrade
	c["auto_generate"] = auto_generate
	return true


func delete_design(design_id: String) -> bool:
	if not _custom_designs.has(design_id):
		return false
	var c: Dictionary = _custom_designs[design_id]
	var empire_id: int = c.get("empire_id", -1)
	_custom_designs.erase(design_id)
	if empire_id >= 0 and _empire_design_ids.has(empire_id):
		var arr: Array = _empire_design_ids[empire_id]
		arr.erase(design_id)
	return true


## Returns display type for galaxy map: "science", "construction", or "military".
func get_ship_display_type(design_id: String) -> String:
	var d: Dictionary = get_design(design_id)
	if d.is_empty():
		return "construction"
	if d.get("category", "") == "military":
		return "military"
	if design_id == "science_ship":
		return "science"
	if design_id == "construction_ship" or design_id == "colony_ship":
		return "construction"
	return "construction"


func get_design_name(design_id: String) -> String:
	var d: Dictionary = get_design(design_id)
	return d.get("name_key", design_id)


func get_design_build_time_months(design_id: String) -> int:
	var d: Dictionary = get_design(design_id)
	return int(d.get("build_time_months", 12))
