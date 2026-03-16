extends Node
## Loads tech definitions, provides draw and completion. Research points applied per empire each month.
## Access via autoload: ResearchManager

var _tech_defs: Array = []


func _ready() -> void:
	_load_techs()


func _load_techs() -> void:
	var path: String = ProjectPaths.DATA_TECHS
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	_tech_defs = json.data if json.data is Array else []


func get_tech_def(tech_id: String) -> Dictionary:
	for t in _tech_defs:
		if t.get("id", "") == tech_id:
			return t
	return {}


## Scene path for this tech's card. Use default tech_card.tscn unless tech has "card_scene".
func get_tech_card_scene_path(tech_def: Dictionary) -> String:
	var path: String = tech_def.get("card_scene", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return "res://ui/components/tech_card.tscn"  # Card scene path; could add to ProjectPaths if needed
	return path


const BRANCH_KEYS: Array = ["physical", "social", "xenological"]
const BRANCH_NAMES: Dictionary = {
	"physical": "Physical Sciences",
	"social": "Social Sciences",
	"xenological": "Xenological Sciences",
}


## Branch key for display; from tech's branch_key if set, else category 0→physical, 1→social, 2→xenological.
func get_tech_branch_key(tech_def: Dictionary) -> String:
	var key: String = tech_def.get("branch_key", "")
	if not key.is_empty():
		return key
	var cat: int = int(tech_def.get("category", 0))
	if cat >= 0 and cat < BRANCH_KEYS.size():
		return BRANCH_KEYS[cat]
	return "physical"


## All techs grouped for tree UI: { "physical": { 1: [tech, ...], 2: [...] }, "social": {...}, "xenological": {...} }
func get_all_techs_grouped_by_branch_and_tier() -> Dictionary:
	var out: Dictionary = {}
	for branch in BRANCH_KEYS:
		out[branch] = {}
	for t in _tech_defs:
		var branch: String = get_tech_branch_key(t)
		if not out.has(branch):
			out[branch] = {}
		var tier: int = int(t.get("tier", 1))
		if not out[branch].has(tier):
			out[branch][tier] = []
		out[branch][tier].append(t)
	return out


## Minimum number of techs of the previous tier (same category) required to show a tier-K tech. Stellaris-style progression.
const TIER_GATE_COUNT: int = 2

func get_available_techs(empire: Empire) -> Array:
	var completed: Array = empire.completed_tech_ids
	var out: Array = []
	for t in _tech_defs:
		var tid: String = t.get("id", "")
		if tid in completed:
			continue
		var prereqs: Array = t.get("prerequisites", [])
		var met: bool = true
		for p in prereqs:
			if p not in completed:
				met = false
				break
		if not met:
			continue
		## Tier gating: tier >= 2 requires TIER_GATE_COUNT techs of (tier-1) in same category.
		var tier: int = int(t.get("tier", 1))
		var category: int = int(t.get("category", 0))
		if tier >= 2 and not _tier_gate_met(empire, category, tier):
			continue
		out.append(t)
	return out


func _tier_gate_met(empire: Empire, category: int, tier: int) -> bool:
	var required_tier: int = tier - 1
	var count: int = 0
	for completed_id in empire.completed_tech_ids:
		var def: Dictionary = get_tech_def(completed_id)
		if def.is_empty():
			continue
		if int(def.get("category", -1)) == category and int(def.get("tier", 0)) == required_tier:
			count += 1
	return count >= TIER_GATE_COUNT


func get_draw(empire: Empire, count: int = 3) -> Array:
	var available: Array = get_available_techs(empire)
	if available.is_empty():
		return []
	available.shuffle()
	return available.slice(0, mini(count, available.size()))


func add_research_progress(empire: Empire, points: float) -> void:
	if empire.current_research_tech_id.is_empty():
		return
	var def: Dictionary = get_tech_def(empire.current_research_tech_id)
	if def.is_empty():
		return
	var bonus: float = _get_scientist_research_bonus(empire)
	points *= (1.0 + bonus)
	var cost: float = float(def.get("cost", 100))
	empire.research_progress += points
	if empire.research_progress >= cost:
		_complete_tech(empire)


func _get_scientist_research_bonus(empire: Empire) -> float:
	var total: float = 0.0
	for l in empire.leaders:
		if l is Leader and (l as Leader).leader_type == Leader.LeaderType.SCIENTIST and (l as Leader).assigned_to_research:
			for tid in (l as Leader).trait_ids:
				var t: Dictionary = _get_trait(tid)
				if t.get("effect", "") == "research_speed":
					total += float(t.get("value", 0))
	return total


func _get_trait(trait_id: String) -> Dictionary:
	if LeaderManager == null:
		return {}
	return LeaderManager.get_trait_def(trait_id)


func _complete_tech(empire: Empire) -> void:
	empire.completed_tech_ids.append(empire.current_research_tech_id)
	empire.current_research_tech_id = ""
	empire.research_progress = 0.0
	_start_next_in_queue(empire)


func _start_next_in_queue(empire: Empire) -> void:
	if empire.current_research_tech_id.is_empty() and empire.research_queue.size() > 0:
		empire.current_research_tech_id = empire.research_queue.pop_front()
		empire.research_progress = 0.0


## Returns ordered list of tech ids (prerequisites first, then target) needed to research target_id.
## Only includes techs not yet completed. Does not filter by tier gate.
func get_ordered_prerequisite_chain(target_id: String) -> Array:
	var out: Array = []
	var visited: Dictionary = {}
	_add_prereq_chain(target_id, visited, out)
	return out


func _add_prereq_chain(tid: String, visited: Dictionary, out: Array) -> void:
	if visited.get(tid, false):
		return
	visited[tid] = true
	var def: Dictionary = get_tech_def(tid)
	if def.is_empty():
		out.append(tid)
		return
	for p in def.get("prerequisites", []):
		_add_prereq_chain(p, visited, out)
	out.append(tid)


## Queue the given tech and all missing prerequisites in order. Starts research if nothing in progress.
func queue_tech_and_prerequisites(empire: Empire, tech_id: String) -> void:
	if empire == null:
		return
	var chain: Array = get_ordered_prerequisite_chain(tech_id)
	var completed: Array = empire.completed_tech_ids
	var in_queue: Dictionary = {}
	for q in empire.research_queue:
		in_queue[q] = true
	var current: String = empire.current_research_tech_id
	for tid in chain:
		if tid in completed or in_queue.get(tid, false) or tid == current:
			continue
		empire.research_queue.append(tid)
		in_queue[tid] = true
	_start_next_in_queue(empire)
