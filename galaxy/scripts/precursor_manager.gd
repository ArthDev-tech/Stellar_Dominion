extends Node
## Handles precursor anomaly surveying and reward granting.
## Access via autoload: PrecursorManager

var _precursor_defs: Array = []


func _ready() -> void:
	_load_precursors()


func _load_precursors() -> void:
	var path: String = ProjectPaths.DATA_PRECURSORS
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
	_precursor_defs = json.data if json.data is Array else []


func get_anomalies_in_system(system_id: int) -> Array:
	if GalaxyManager == null or GalaxyManager.galaxy == null:
		return []
	var out: Array = []
	for a in GalaxyManager.galaxy.anomalies:
		if a.system_id == system_id:
			out.append(a)
	return out


func get_unsurveyed_anomaly_in_system(system_id: int) -> Anomaly:
	var list: Array = get_anomalies_in_system(system_id)
	for a in list:
		if not a.is_surveyed():
			return a as Anomaly
	return null


func survey_anomaly(empire: Empire, anomaly: Anomaly) -> bool:
	if anomaly == null or anomaly.is_surveyed():
		return false
	anomaly.surveyed_by_empire_id = empire.id
	var pid: String = anomaly.precursor_id
	empire.precursor_progress[pid] = empire.precursor_progress.get(pid, 0) + 1
	var count: int = empire.precursor_progress.get(pid, 0)
	var def: Dictionary = _get_precursor_def(pid)
	var required: int = def.get("anomalies_required", 6)
	if count >= required:
		_grant_reward(empire, def)
	return true


func _get_precursor_def(precursor_id: String) -> Dictionary:
	for p in _precursor_defs:
		if p.get("id", "") == precursor_id:
			return p
	return {}


func _grant_reward(empire: Empire, def: Dictionary) -> void:
	var tech: String = def.get("reward_tech", "")
	if not tech.is_empty() and tech not in empire.completed_tech_ids:
		empire.completed_tech_ids.append(tech)
	var e: float = float(def.get("reward_energy", 0))
	var m: float = float(def.get("reward_minerals", 0))
	if e > 0:
		empire.resources.add_amount(GameResources.ResourceType.ENERGY, e)
	if m > 0:
		empire.resources.add_amount(GameResources.ResourceType.MINERALS, m)
