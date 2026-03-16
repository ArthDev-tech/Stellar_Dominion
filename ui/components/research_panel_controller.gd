class_name ResearchPanelController
extends RefCounted
## Updates the research panel (label + tech draw buttons). Used by GameScene.

var _research_label: Label
var _tech1_btn: Button
var _tech2_btn: Button
var _tech3_btn: Button


func setup(research_label: Label, tech1_btn: Button, tech2_btn: Button, tech3_btn: Button) -> void:
	_research_label = research_label
	_tech1_btn = tech1_btn
	_tech2_btn = tech2_btn
	_tech3_btn = tech3_btn


func update_research_panel() -> void:
	if _research_label == null or _tech1_btn == null or EmpireManager == null or ResearchManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	if not player_emp.current_research_tech_id.is_empty():
		var def: Dictionary = ResearchManager.get_tech_def(player_emp.current_research_tech_id)
		var cost: float = float(def.get("cost", 100))
		_research_label.text = "%s\n%.0f / %.0f" % [def.get("name_key", "?"), player_emp.research_progress, cost]
		_tech1_btn.visible = false
		_tech2_btn.visible = false
		_tech3_btn.visible = false
	else:
		var tech_draw: Array = ResearchManager.get_draw(player_emp, 3)
		_research_label.text = "Choose a tech to research:" if tech_draw.size() > 0 else "No techs available (research more to unlock)."
		_tech1_btn.visible = tech_draw.size() > 0
		_tech2_btn.visible = tech_draw.size() > 1
		_tech3_btn.visible = tech_draw.size() > 2
		if tech_draw.size() > 0:
			_tech1_btn.text = tech_draw[0].get("name_key", "?")
		if tech_draw.size() > 1:
			_tech2_btn.text = tech_draw[1].get("name_key", "?")
		if tech_draw.size() > 2:
			_tech3_btn.text = tech_draw[2].get("name_key", "?")


func pick_tech_from_draw(index: int) -> bool:
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp == null or ResearchManager == null or player_emp.current_research_tech_id != "":
		return false
	var tech_draw: Array = ResearchManager.get_draw(player_emp, 3)
	if index < 0 or index >= tech_draw.size():
		return false
	player_emp.current_research_tech_id = tech_draw[index].get("id", "")
	player_emp.research_progress = 0.0
	return true
