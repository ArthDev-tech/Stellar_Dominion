extends DraggableOverlay
## Ship Designer: edit loadouts, create/save/delete custom designs. Open from Shipyard or global nav.

signal closed

var _empire: Empire
var _current_design_id: String = ""
var _current_hull_id: String = ""
var _current_loadout: Dictionary = {}
var _current_name_key: String = ""
var _current_ship_role: String = "Custom"
var _current_auto_upgrade: bool = false
var _current_auto_generate: bool = false
var _selected_slot_id: String = ""
var _design_buttons: Array = []

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Margin/VBox/TitleBar/CloseButton
@onready var design_list_vbox: VBoxContainer = $Margin/VBox/MainHBox/DesignListPanel/DesignListScroll/DesignListVBox
@onready var ship_placeholder: Label = $Margin/VBox/MainHBox/CenterPanel/ShipPlaceholder
@onready var slots_grid: GridContainer = $Margin/VBox/MainHBox/CenterPanel/SlotsGrid
@onready var stats_label: Label = $Margin/VBox/MainHBox/RightPanel/StatsPanel/StatsLabel
@onready var category_strip: HBoxContainer = $Margin/VBox/MainHBox/RightPanel/ComponentCategoryStrip
@onready var component_list_vbox: VBoxContainer = $Margin/VBox/MainHBox/RightPanel/ComponentListScroll/ComponentListVBox
@onready var hull_option: OptionButton = $Margin/VBox/MainHBox/RightPanel/HullRow/HullOption
@onready var ship_name_edit: LineEdit = $Margin/VBox/MainHBox/RightPanel/ShipNameRow/ShipNameEdit
@onready var ship_role_option: OptionButton = $Margin/VBox/MainHBox/RightPanel/ShipRoleRow/ShipRoleOption
@onready var auto_upgrade_check: CheckBox = $Margin/VBox/MainHBox/RightPanel/AutoCheckboxes/AutoUpgradeCheck
@onready var auto_generate_check: CheckBox = $Margin/VBox/MainHBox/RightPanel/AutoCheckboxes/AutoGenerateCheck
@onready var new_design_button: Button = $Margin/VBox/MainHBox/RightPanel/ActionsHBox/NewDesignButton
@onready var save_design_button: Button = $Margin/VBox/MainHBox/RightPanel/ActionsHBox/SaveDesignButton
@onready var delete_design_button: Button = $Margin/VBox/MainHBox/RightPanel/ActionsHBox/DeleteDesignButton


func _ready() -> void:
	# Apply theme so panel is styled when shown on overlay CanvasLayer (no root theme inheritance)
	var root_theme: Theme = get_tree().root.theme
	if root_theme != null:
		theme = root_theme
	elif ResourceLoader.exists("res://assets/themes/stellar_dominion_theme.tres"):
		theme = load("res://assets/themes/stellar_dominion_theme.tres") as Theme
	close_button.pressed.connect(_on_close_pressed)
	new_design_button.pressed.connect(_on_new_design_pressed)
	save_design_button.pressed.connect(_on_save_design_pressed)
	delete_design_button.pressed.connect(_on_delete_design_pressed)
	if hull_option != null:
		hull_option.item_selected.connect(_on_hull_selected)
	ship_name_edit.text_changed.connect(_on_ship_name_changed)
	ship_role_option.item_selected.connect(_on_ship_role_selected)
	auto_upgrade_check.toggled.connect(_on_auto_upgrade_toggled)
	auto_generate_check.toggled.connect(_on_auto_generate_toggled)
	if title_label != null:
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _empire != null:
		_refresh_all()


func setup(empire: Empire) -> void:
	_empire = empire
	_refresh_all()


func _refresh_all() -> void:
	_refresh_design_list()
	_refresh_hull_option()
	_refresh_slots_and_stats()
	_refresh_component_list()
	_refresh_fields()
	_update_action_buttons()


func _refresh_design_list() -> void:
	if design_list_vbox == null:
		return
	for c in design_list_vbox.get_children():
		c.queue_free()
	_design_buttons.clear()
	if _empire == null or ShipDesignManager == null:
		return
	var designs: Array = ShipDesignManager.get_designs_for_empire(_empire.id)
	for d in designs:
		var did: String = d.get("id", "")
		var name_key: String = d.get("name_key", did)
		var is_custom: bool = d.get("is_custom", false)
		var btn: Button = Button.new()
		btn.text = ("* " if is_custom else "") + name_key
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_design_list_item_pressed.bind(did))
		design_list_vbox.add_child(btn)
		_design_buttons.append(btn)


func _on_design_list_item_pressed(design_id: String) -> void:
	var d: Dictionary = ShipDesignManager.get_design(design_id) if ShipDesignManager != null else {}
	if d.is_empty():
		return
	_current_design_id = design_id
	_current_hull_id = d.get("hull_id", "")
	_current_loadout = d.get("loadout", {}).duplicate()
	# Default missing star_drive slot to drive_impulse_1.
	if ShipDesignManager != null:
		var hull: Dictionary = ShipDesignManager.get_hull(_current_hull_id)
		for slot_def in hull.get("slots", []):
			if slot_def.get("type", "") == "star_drive":
				var sid: String = slot_def.get("id", "")
				if _current_loadout.get(sid, "").is_empty():
					_current_loadout[sid] = "drive_impulse_1"
	_current_name_key = d.get("name_key", "Custom")
	_current_ship_role = d.get("ship_role", "Custom")
	_current_auto_upgrade = d.get("auto_upgrade", false)
	_current_auto_generate = d.get("auto_generate", false)
	_selected_slot_id = ""
	_refresh_hull_option()
	_refresh_slots_and_stats()
	_refresh_component_list()
	_refresh_fields()
	_update_action_buttons()


func _refresh_hull_option() -> void:
	if hull_option == null or ShipDesignManager == null:
		return
	var hulls: Array = ShipDesignManager.get_all_hulls()
	hull_option.clear()
	var idx: int = 0
	var select_idx: int = 0
	for h in hulls:
		var hid: String = h.get("id", "")
		var name_key: String = h.get("name_key", hid)
		hull_option.add_item(name_key, idx)
		if hid == _current_hull_id:
			select_idx = idx
		idx += 1
	if hulls.size() > 0:
		hull_option.select(select_idx)


func _on_hull_selected(index: int) -> void:
	if ShipDesignManager == null or hull_option == null:
		return
	var hulls: Array = ShipDesignManager.get_all_hulls()
	if index < 0 or index >= hulls.size():
		return
	var hull_id: String = hulls[index].get("id", "")
	if hull_id == _current_hull_id:
		return
	_current_hull_id = hull_id
	_current_loadout = {}
	_selected_slot_id = ""
	_refresh_slots_and_stats()
	_refresh_component_list()
	_refresh_fields()
	_update_action_buttons()


func _refresh_slots_and_stats() -> void:
	for c in slots_grid.get_children():
		c.queue_free()
	if _current_hull_id.is_empty():
		ship_placeholder.text = "Select a design or create new"
		stats_label.text = "Build time: —\nUpkeep: —\nCost: —\nPower: —\nHull / Armor / Shields: —\nEvasion: —\nSpeed: —\nDamage: —"
		return
	var hull: Dictionary = ShipDesignManager.get_hull(_current_hull_id) if ShipDesignManager != null else {}
	var slots: Array = hull.get("slots", [])
	ship_placeholder.text = hull.get("name_key", _current_hull_id)
	slots_grid.columns = min(4, max(1, slots.size()))
	for slot_def in slots:
		var slot_id: String = slot_def.get("id", "")
		var slot_type: String = slot_def.get("type", "")
		var _slot_size: String = slot_def.get("size", "S")
		var comp_id: String = _current_loadout.get(slot_id, "")
		var comp_name: String = "Empty"
		if not comp_id.is_empty() and ShipDesignManager != null:
			var comp: Dictionary = ShipDesignManager.get_component(comp_id)
			comp_name = comp.get("name_key", comp_id)
			if slot_type == "star_drive":
				var mod: float = float(comp.get("transit_time_modifier", 1.0))
				comp_name = "%s — %d%% transit time" % [comp_name, int(mod * 100)]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(100, 44)
		btn.text = "%s\n%s" % [slot_id, comp_name]
		btn.flat = true
		btn.toggle_mode = true
		btn.button_pressed = (_selected_slot_id == slot_id)
		btn.pressed.connect(_on_slot_pressed.bind(slot_id))
		slots_grid.add_child(btn)
	var stats: Dictionary = ShipDesignManager.compute_design_stats(_current_hull_id, _current_loadout) if ShipDesignManager != null else {}
	var cost: Dictionary = ShipDesignManager.compute_design_cost(_current_hull_id, _current_loadout) if ShipDesignManager != null else {}
	var upkeep: Dictionary = ShipDesignManager.compute_design_upkeep(_current_hull_id, _current_loadout) if ShipDesignManager != null else {}
	var build_time: int = ShipDesignManager.compute_build_time_months(_current_hull_id, _current_loadout) if ShipDesignManager != null else 0
	var cost_str: String = _format_resource_dict(cost)
	var upkeep_str: String = _format_resource_dict(upkeep)
	var power: float = stats.get("power", 0.0)
	var power_str: String = "%.0f" % power
	if power < 0:
		power_str += " (over)"
	stats_label.text = "Build time: %d months\nUpkeep: %s\nCost: %s\nPower: %s\nHull: %.0f  Armor: %.0f  Shields: %.0f\nEvasion: %.1f%%\nSpeed: %.2f\nDamage: %.2f\nSensor range: %d" % [
		build_time,
		upkeep_str if not upkeep_str.is_empty() else "—",
		cost_str if not cost_str.is_empty() else "—",
		power_str,
		stats.get("hull", 0),
		stats.get("armor", 0),
		stats.get("shields", 0),
		stats.get("evasion", 0),
		stats.get("speed", 0),
		stats.get("damage", 0),
		int(stats.get("sensor_range", 0))
	]


func _format_resource_dict(rd: Dictionary) -> String:
	var parts: PackedStringArray = []
	for rt in rd:
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		parts.append("%s %.1f" % [short, rd[rt]])
	return ", ".join(parts)


func _on_slot_pressed(slot_id: String) -> void:
	_selected_slot_id = slot_id
	_refresh_slots_and_stats()
	_refresh_component_list()


func _refresh_component_list() -> void:
	for c in component_list_vbox.get_children():
		c.queue_free()
	if _selected_slot_id.is_empty() or _current_hull_id.is_empty() or ShipDesignManager == null:
		return
	var hull: Dictionary = ShipDesignManager.get_hull(_current_hull_id)
	var slots: Array = hull.get("slots", [])
	var slot_type: String = ""
	var slot_size: String = "S"
	for s in slots:
		if s.get("id", "") == _selected_slot_id:
			slot_type = s.get("type", "")
			slot_size = s.get("size", "S")
			break
	var components: Array = ShipDesignManager.get_components_for_slot(slot_type, slot_size, _empire)
	for comp in components:
		var cid: String = comp.get("id", "")
		var name_key: String = comp.get("name_key", cid)
		var tier: int = int(comp.get("tier", 0))
		var display_text: String = name_key
		if tier >= 1:
			display_text = "%s (T%d)" % [name_key, tier]
		var btn: Button = Button.new()
		btn.text = display_text
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_component_pressed.bind(cid))
		component_list_vbox.add_child(btn)


func _on_component_pressed(component_id: String) -> void:
	if _selected_slot_id.is_empty():
		return
	_current_loadout[_selected_slot_id] = component_id
	_refresh_slots_and_stats()
	_refresh_component_list()


func _refresh_fields() -> void:
	if hull_option != null and ShipDesignManager != null:
		var hulls: Array = ShipDesignManager.get_all_hulls()
		for i in hulls.size():
			if hulls[i].get("id", "") == _current_hull_id:
				hull_option.select(i)
				break
	ship_name_edit.text = _current_name_key
	ship_role_option.selected = 0 if _current_ship_role != "Interceptor" else 1
	auto_upgrade_check.button_pressed = _current_auto_upgrade
	auto_generate_check.button_pressed = _current_auto_generate


func _update_action_buttons() -> void:
	var has_design: bool = not _current_design_id.is_empty()
	var is_custom: bool = false
	if has_design and ShipDesignManager != null:
		var d: Dictionary = ShipDesignManager.get_design(_current_design_id)
		is_custom = d.get("is_custom", false)
	save_design_button.disabled = _current_hull_id.is_empty()
	delete_design_button.visible = is_custom
	delete_design_button.disabled = not is_custom


func _on_ship_name_changed(new_text: String) -> void:
	_current_name_key = new_text


func _on_ship_role_selected(index: int) -> void:
	_current_ship_role = ship_role_option.get_item_text(index)


func _on_auto_upgrade_toggled(pressed: bool) -> void:
	_current_auto_upgrade = pressed


func _on_auto_generate_toggled(pressed: bool) -> void:
	_current_auto_generate = pressed


func _on_new_design_pressed() -> void:
	if ShipDesignManager == null or _empire == null:
		return
	var hulls: Array = ShipDesignManager.get_all_hulls()
	if hulls.is_empty():
		return
	var hull_id: String = hulls[0].get("id", "")
	for h in hulls:
		if h.get("category", "") == "military":
			hull_id = h.get("id", "")
			break
	_current_design_id = ""
	_current_hull_id = hull_id
	_current_loadout = {}
	_current_name_key = "New design"
	_current_ship_role = "Custom"
	_current_auto_upgrade = false
	_current_auto_generate = false
	_selected_slot_id = ""
	_refresh_all()


func _on_save_design_pressed() -> void:
	if ShipDesignManager == null or _empire == null or _current_hull_id.is_empty():
		return
	if _current_design_id.is_empty() or not ShipDesignManager.get_design(_current_design_id).get("is_custom", false):
		_current_design_id = ShipDesignManager.create_design(_empire.id, _current_hull_id, _current_name_key, _current_loadout, _current_ship_role, _current_auto_upgrade, _current_auto_generate)
	else:
		ShipDesignManager.update_design(_current_design_id, _current_name_key, _current_loadout, _current_ship_role, _current_auto_upgrade, _current_auto_generate)
	_refresh_design_list()
	_update_action_buttons()


func _on_delete_design_pressed() -> void:
	if ShipDesignManager == null or _current_design_id.is_empty():
		return
	var d: Dictionary = ShipDesignManager.get_design(_current_design_id)
	if not d.get("is_custom", false):
		return
	ShipDesignManager.delete_design(_current_design_id)
	_current_design_id = ""
	_current_hull_id = ""
	_current_loadout = {}
	_current_name_key = ""
	_selected_slot_id = ""
	_refresh_all()


func _on_close_pressed() -> void:
	closed.emit()
