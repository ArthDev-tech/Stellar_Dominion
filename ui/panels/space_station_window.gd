extends DraggableOverlay
## Space station construction window with sub-tabs: Command, Defenses, Shipyard.
## Stellaris-style: ship designs list and build queue in Shipyard tab.

signal closed
signal open_ship_designer_requested(empire: Empire)

var _station: SpaceStation
var _empire: Empire

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Margin/VBox/TitleBar/CloseButton
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer
@onready var command_content: VBoxContainer = $Margin/VBox/TabContainer/Command
@onready var buildings_grid: GridContainer = $Margin/VBox/TabContainer/Buildings/BuildingsGrid
@onready var defenses_content: VBoxContainer = $Margin/VBox/TabContainer/Defenses
@onready var shipyard_queue: VBoxContainer = $Margin/VBox/TabContainer/Shipyard/ShipyardHBox/QueuePanel/QueueScroll/QueueVBox
@onready var shipyard_designs: VBoxContainer = $Margin/VBox/TabContainer/Shipyard/ShipyardHBox/DesignsPanel/DesignsScroll/DesignsVBox

var _station_build_popup: PopupMenu
var _buildable_station_module_ids: Array = []


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a0f1c")
	style.border_color = Color("#1e3a5f")
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	add_theme_stylebox_override("panel", style)
	close_button.pressed.connect(_on_close_pressed)
	# Let the title bar (drag handle) receive clicks instead of the label
	if title_label != null:
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# If setup() was called before we were in the tree, @onready vars are now valid; apply and refresh.
	if _station != null and _empire != null:
		title_label.text = _station.name_key
		_refresh_all()


func setup(station: SpaceStation, empire: Empire) -> void:
	_station = station
	_empire = empire
	if title_label != null:
		title_label.text = station.name_key
	if tab_container != null:
		_refresh_all()


func _refresh_all() -> void:
	_refresh_command()
	_refresh_buildings()
	_refresh_defenses()
	_refresh_shipyard()


func _refresh_command() -> void:
	for c in command_content.get_children():
		c.queue_free()
	var slots: int = _station.get_station_building_slots() if _station != null else 6
	var used: int = _station.station_buildings.size() if _station != null else 0
	var lbl: Label = Label.new()
	lbl.text = "Station command and overview.\nBuilding slots: %d / %d\nShip build queue in Shipyard tab." % [used, slots]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	command_content.add_child(lbl)


func _refresh_buildings() -> void:
	if buildings_grid == null or _station == null:
		return
	for c in buildings_grid.get_children():
		c.queue_free()
	var defs: Array = _load_building_defs()
	var name_by_id: Dictionary = {}
	var def_by_id: Dictionary = {}
	_buildable_station_module_ids.clear()
	for d in defs:
		var bid: String = d.get("id", "")
		if d.get("station_module", false):
			_buildable_station_module_ids.append(bid)
		name_by_id[bid] = d.get("name_key", bid)
		def_by_id[bid] = d
	var slots: int = _station.get_station_building_slots()
	if _station_build_popup == null:
		_station_build_popup = PopupMenu.new()
		add_child(_station_build_popup)
		_station_build_popup.id_pressed.connect(_on_station_build_menu_id_pressed)
	buildings_grid.columns = 3
	for i in range(slots):
		if i < _station.station_buildings.size():
			var bid: String = _station.station_buildings[i]
			var cell: Button = Button.new()
			cell.custom_minimum_size = Vector2(120, 56)
			cell.text = name_by_id.get(bid, bid)
			cell.flat = true
			cell.disabled = true
			buildings_grid.add_child(cell)
		else:
			var build_btn: Button = Button.new()
			build_btn.custom_minimum_size = Vector2(120, 56)
			build_btn.text = "+ Build"
			build_btn.pressed.connect(_on_station_empty_slot_pressed.bind(build_btn))
			buildings_grid.add_child(build_btn)


func _load_building_defs() -> Array:
	return Colony.get_all_building_defs()


func _on_station_empty_slot_pressed(button: Button) -> void:
	_station_build_popup.clear()
	if _station.station_buildings.size() >= _station.get_station_building_slots():
		return
	for idx in range(_buildable_station_module_ids.size()):
		var bid: String = _buildable_station_module_ids[idx]
		var def: Dictionary = {}
		for d in _load_building_defs():
			if d.get("id", "") == bid:
				def = d
				break
		var name_key: String = def.get("name_key", bid)
		var cost: Dictionary = _cost_dict_from_json(def.get("cost", {}))
		var cost_str: String = _format_cost(cost)
		var label: String = name_key if cost_str.is_empty() else "%s (%s)" % [name_key, cost_str]
		_station_build_popup.add_item(label, idx)
	_station_build_popup.position = button.get_global_position() + Vector2(0, button.size.y)
	_station_build_popup.popup()


func _on_station_build_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= _buildable_station_module_ids.size():
		return
	var building_id: String = _buildable_station_module_ids[id]
	if _station.add_building(building_id, _empire):
		_refresh_buildings()
		_refresh_command()


func _refresh_defenses() -> void:
	for c in defenses_content.get_children():
		c.queue_free()
	var lbl: Label = Label.new()
	lbl.text = "Defense modules and hull upgrades (coming soon)."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	defenses_content.add_child(lbl)


func _refresh_shipyard() -> void:
	for c in shipyard_queue.get_children():
		c.queue_free()
	var shipyard_count: int = _station.get_shipyard_count() if _station != null else 0
	var q_header: Label = Label.new()
	q_header.text = "Ship build queue" + (" (%d shipyard(s))" % shipyard_count if shipyard_count > 0 else " — Build a Small Shipyard or Medium Shipyard in the Buildings tab to construct ships.")
	q_header.add_theme_font_size_override("font_size", 14)
	q_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shipyard_queue.add_child(q_header)
	if shipyard_count <= 0:
		var msg: Label = Label.new()
		msg.text = "Add shipyard modules in the Buildings tab to enable ship construction."
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shipyard_queue.add_child(msg)
	for i in _station.ship_build_queue.size():
		var entry: Variant = _station.ship_build_queue[i]
		if entry is Dictionary:
			var design_id: String = entry.get("design_id", "")
			var progress: int = int(entry.get("progress_months", 0))
			var def: Dictionary = _get_design_def(design_id)
			var name_key: String = def.get("name_key", design_id)
			var months: int = int(def.get("build_time_months", 12))
			var row: Label = Label.new()
			row.text = "%d. %s (%d/%d months)" % [i + 1, name_key, progress, months]
			shipyard_queue.add_child(row)
		else:
			var row: Label = Label.new()
			row.text = "%d. %s" % [i + 1, str(entry)]
			shipyard_queue.add_child(row)
	for c in shipyard_designs.get_children():
		c.queue_free()
	var design_ships_btn: Button = Button.new()
	design_ships_btn.text = "Design ships..."
	design_ships_btn.pressed.connect(_on_design_ships_pressed)
	shipyard_designs.add_child(design_ships_btn)
	var d_header: Label = Label.new()
	d_header.text = "Ship designs"
	d_header.add_theme_font_size_override("font_size", 14)
	shipyard_designs.add_child(d_header)
	var designs: Array = _load_ship_designs()
	var by_category: Dictionary = {}
	for d in designs:
		var cat: String = d.get("category", "other")
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(d)
	for cat in ["civilian", "military", "other"]:
		if not by_category.has(cat):
			continue
		var cat_header: Label = Label.new()
		cat_header.text = cat.capitalize() + " Ships"
		cat_header.add_theme_font_size_override("font_size", 14)
		shipyard_designs.add_child(cat_header)
		for d in by_category[cat]:
			var design_id: String = d.get("id", "")
			var name_key: String = d.get("name_key", design_id)
			var cost: Dictionary = _cost_dict_from_json(d.get("cost", {}))
			var cost_str: String = _format_cost(cost)
			var months: int = int(d.get("build_time_months", 12))
			var btn: Button = Button.new()
			btn.text = "%s — %s (%d months)" % [name_key, cost_str, months]
			btn.disabled = shipyard_count <= 0
			btn.pressed.connect(_on_build_design_pressed.bind(design_id))
			shipyard_designs.add_child(btn)


func _get_design_def(design_id: String) -> Dictionary:
	if ShipDesignManager != null:
		return ShipDesignManager.get_design(design_id)
	return {}


func _load_ship_designs() -> Array:
	if ShipDesignManager != null and _empire != null:
		return ShipDesignManager.get_designs_for_empire(_empire.id)
	return []


func _cost_dict_from_json(cost_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cost_json:
		var rt: int = int(key)
		if rt >= 0 and rt < GameResources.ResourceType.LAST:
			out[rt as GameResources.ResourceType] = float(cost_json[key])
	return out


func _format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for rt in cost:
		var name_str: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		parts.append("%d %s" % [int(cost[rt]), name_str])
	return ", ".join(parts)


func _on_design_ships_pressed() -> void:
	if _empire != null:
		open_ship_designer_requested.emit(_empire)


func _on_build_design_pressed(design_id: String) -> void:
	if _station == null or _empire == null:
		return
	if _station.get_shipyard_count() <= 0:
		return
	var def: Dictionary = _get_design_def(design_id)
	if def.is_empty():
		return
	var cost: Dictionary = _cost_dict_from_json(def.get("cost", {}))
	if not _empire.resources.can_afford(cost):
		return
	_empire.resources.pay(cost)
	_station.queue_ship(design_id)
	_refresh_shipyard()


func _on_close_pressed() -> void:
	closed.emit()
