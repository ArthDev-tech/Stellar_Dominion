extends DraggablePanel
## Fleet panel: selected ships from SelectionManager; filter is display-only.

@export_group("Panel")
@export var panel_color: Color = Color(0.08, 0.12, 0.18, 0.92)
@export var max_visible_ships_before_scroll: int = 8
@export var transit_ui_refresh_seconds: float = 0.2

var _fleet_name_label: Label
var _fleet_power_label: Label
var _ship_list_container: VBoxContainer
var _total_count_label: Label
var _scroll_container: ScrollContainer
var _title_label: Label
var _deselect_btn: Button
var _context_label: Label
var _transit_refresh_acc: float = 0.0


func _ready() -> void:
	super._ready()
	_title_label = get_node_or_null("TitleBar/TitleLabel") as Label
	_deselect_btn = get_node_or_null("TitleBar/DeselectAllButton") as Button
	if _deselect_btn != null:
		_deselect_btn.pressed.connect(_on_deselect_all_pressed)
	_fleet_name_label = get_node_or_null("MarginContainer/VBoxContainer/FleetNameLabel") as Label
	_fleet_power_label = get_node_or_null("MarginContainer/VBoxContainer/FleetPowerLabel") as Label
	_scroll_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer") as ScrollContainer
	_ship_list_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/ShipListContainer") as VBoxContainer
	_total_count_label = get_node_or_null("MarginContainer/VBoxContainer/TotalCountLabel") as Label
	_context_label = get_node_or_null("MarginContainer/VBoxContainer/ContextLabel") as Label
	_add_panel_style()
	visible = true
	if SelectionManager != null:
		SelectionManager.selection_changed.connect(_on_selection_changed)
		SelectionManager.filter_changed.connect(_on_filter_changed)
	_refresh_panel()


func _process(delta: float) -> void:
	if not visible or SelectionManager == null:
		return
	var any_transit: bool = false
	for sd in SelectionManager.selected_ships:
		if sd.transit_days_remaining > 0:
			any_transit = true
			break
	if not any_transit:
		return
	_transit_refresh_acc += delta
	if _transit_refresh_acc < transit_ui_refresh_seconds:
		return
	_transit_refresh_acc = 0.0
	SelectionManager.sync_selected_ship_locations_from_empire()
	_refresh_panel()


func _on_deselect_all_pressed() -> void:
	if SelectionManager != null:
		SelectionManager.set_selection([])


func _add_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.4, 0.55, 0.6)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


func clear_ship_connections() -> void:
	pass


func _on_selection_changed(_ships: Array) -> void:
	_refresh_panel()


func _on_filter_changed(_filter: String) -> void:
	_refresh_panel()


func _display_bucket(sd: ShipData) -> String:
	var c: String = sd.ship_class.to_lower()
	if c == "science":
		return "science"
	if c == "construction" or c == "constructor":
		return "construction"
	return "military"


func _passes_filter(sd: ShipData, f: String) -> bool:
	if f == "all":
		return true
	if f == "station":
		return false
	return _display_bucket(sd) == f


func _refresh_panel() -> void:
	clear_ship_connections()
	visible = true
	if _deselect_btn != null:
		_deselect_btn.visible = SelectionManager != null and not SelectionManager.selected_ships.is_empty()
	if SelectionManager != null:
		SelectionManager.sync_selected_ship_locations_from_empire()
	if _ship_list_container != null:
		for c in _ship_list_container.get_children():
			c.queue_free()
	if SelectionManager == null:
		_set_header_fleet_empty()
		return
	var all_sel: Array[ShipData] = SelectionManager.selected_ships
	var n: int = all_sel.size()
	if _title_label != null:
		_title_label.text = ("[%d] ships selected" % n) if n > 0 else "Fleet"
	if all_sel.is_empty():
		if _fleet_name_label != null:
			_fleet_name_label.text = ""
		if _fleet_power_label != null:
			_fleet_power_label.text = ""
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No ships selected"
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ship_list_container.add_child(empty_lbl)
		if _total_count_label != null:
			_total_count_label.text = ""
		if _scroll_container != null:
			_scroll_container.custom_minimum_size.y = 72.0
		if _context_label != null:
			_context_label.text = ""
		return
	if _fleet_name_label != null:
		_fleet_name_label.text = ""
	var filt: String = SelectionManager.selection_filter
	var filtered: Array[ShipData] = []
	for sd in all_sel:
		if _passes_filter(sd, filt):
			filtered.append(sd)
	var power_sum: int = 0
	for sd in all_sel:
		power_sum += int(sd.combat_power)
	if _fleet_power_label != null:
		_fleet_power_label.text = "Filter: %s  |  Power: %s" % [filt.capitalize(), _format_number(power_sum)]
	if filtered.is_empty():
		var msg: Label = Label.new()
		msg.text = "No ships match this filter (%d selected elsewhere)" % all_sel.size()
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ship_list_container.add_child(msg)
	else:
		for sd in filtered:
			_ship_list_container.add_child(_make_ship_row(sd))
	if _scroll_container != null:
		var max_h: float = max_visible_ships_before_scroll * 56.0
		_scroll_container.custom_minimum_size.y = minf(max_h, maxf(72.0, filtered.size() * 56.0))
	if _total_count_label != null:
		_total_count_label.text = "%d shown" % filtered.size()
	if _context_label != null:
		_context_label.text = _build_context_text(all_sel)


func _set_header_fleet_empty() -> void:
	if _title_label != null:
		_title_label.text = "Fleet"
	if _fleet_name_label != null:
		_fleet_name_label.text = ""
	if _fleet_power_label != null:
		_fleet_power_label.text = ""
	var empty_lbl: Label = Label.new()
	empty_lbl.text = "No ships selected"
	_ship_list_container.add_child(empty_lbl)
	if _context_label != null:
		_context_label.text = ""


func _player_empire() -> Empire:
	if EmpireManager == null:
		return null
	return EmpireManager.get_player_empire()


func _resolve_ship(sd: ShipData) -> Ship:
	var emp: Empire = _player_empire()
	if emp == null or sd == null:
		return null
	for s in emp.ships:
		var ship: Ship = s as Ship
		if ship != null and sd.matches_ship(ship):
			return ship
		if ship != null and ship.name_key == sd.ship_name and ship.empire_id == sd.galaxy_empire_id:
			return ship
	return null


func _system_label(ship: Ship) -> String:
	if ship == null or GalaxyManager == null:
		return "—"
	if ship.in_hyperlane:
		var dest: StarSystem = GalaxyManager.get_system(ship.hyperlane_to_system_id)
		var dn: String = dest.name_key if dest != null and dest.name_key != "" else "?"
		return "En route to %s" % dn
	var sys: StarSystem = GalaxyManager.get_system(ship.system_id)
	if sys == null:
		return "System %d" % ship.system_id
	return sys.name_key if sys.name_key != "" else ("System %d" % ship.system_id)


func _order_summary(ship: Ship) -> String:
	if ship == null:
		return "—"
	if ship.has_build_order():
		return "Constructing"
	if ship.in_hyperlane:
		var dest: StarSystem = GalaxyManager.get_system(ship.hyperlane_to_system_id) if GalaxyManager != null else null
		var nm: String = dest.name_key if dest != null and dest.name_key != "" else "?"
		var days_remaining: int = ceili((1.0 - ship.hyperlane_progress) * float(ship.hyperlane_transit_days))
		return "In transit: %s — %d days" % [nm, days_remaining]
	if ship.target_system_id >= 0:
		var dest2: StarSystem = GalaxyManager.get_system(ship.target_system_id) if GalaxyManager != null else null
		var nm2: String = dest2.name_key if dest2 != null and dest2.name_key != "" else "?"
		return "Moving to %s" % nm2
	if ship.path_queue.size() > 0:
		var nxt: int = ship.path_queue[0]
		var dest3: StarSystem = GalaxyManager.get_system(nxt) if GalaxyManager != null else null
		var nm3: String = dest3.name_key if dest3 != null and dest3.name_key != "" else "?"
		return "Route via %s" % nm3
	return "Idle"


func _build_context_text(all_sel: Array[ShipData]) -> String:
	var idle_same_system: bool = true
	var first_sid: int = -2
	var any_transit: bool = false
	var fastest: int = 999999
	for sd in all_sel:
		var sh: Ship = _resolve_ship(sd)
		if sh == null:
			continue
		if sh.in_hyperlane:
			any_transit = true
			var d: int = ceili((1.0 - sh.hyperlane_progress) * float(sh.hyperlane_transit_days))
			fastest = mini(fastest, d)
			idle_same_system = false
		else:
			if first_sid == -2:
				first_sid = sh.system_id
			elif first_sid != sh.system_id:
				idle_same_system = false
	var parts: PackedStringArray = []
	if idle_same_system and not any_transit and first_sid >= 0 and all_sel.size() > 0:
		var all_idle: bool = true
		for sd2 in all_sel:
			var sh2: Ship = _resolve_ship(sd2)
			if sh2 == null or sh2.in_hyperlane or sh2.target_system_id >= 0 or sh2.path_queue.size() > 0 or sh2.has_build_order():
				all_idle = false
				break
		if all_idle:
			parts.append("Move selected ships: right-click a connected system on the galaxy map.")
	if any_transit:
		if fastest >= 999999:
			fastest = 0
		parts.append("In transit — %d days remaining (fastest arrival)" % fastest)
	if parts.is_empty():
		return ""
	return "\n".join(parts)


func _make_ship_row(sd: ShipData) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	var class_color: Color = Color(0.8, 0.8, 0.7)
	match _display_bucket(sd):
		"science":
			class_color = Color(0.4, 0.7, 1.0)
		"construction":
			class_color = Color(0.95, 0.85, 0.3)
		_:
			class_color = Color(0.95, 0.35, 0.3)
	icon.color = class_color
	row.add_child(icon)
	var name_lbl: Label = Label.new()
	var disp_class: String = sd.ship_class if sd.ship_class != "" else "ship"
	name_lbl.text = "%s  (%s)" % [
		sd.ship_name if sd.ship_name != "" else disp_class,
		disp_class
	]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)
	var hull_max: float = sd.hull_max if sd.hull_max > 0 else 1.0
	var ratio: float = clampf(sd.hull_current / hull_max, 0.0, 1.0)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 12)
	bar.max_value = 1.0
	bar.value = ratio
	bar.show_percentage = false
	row.add_child(bar)
	block.add_child(row)
	var live: Ship = _resolve_ship(sd)
	var detail: Label = Label.new()
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84, 1.0))
	detail.text = "Orders: %s  |  Location: %s" % [_order_summary(live), _system_label(live)]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(detail)
	if sd.transit_days_total > 0 and sd.transit_days_remaining >= 0:
		var tbar: ProgressBar = ProgressBar.new()
		tbar.custom_minimum_size = Vector2(0, 6)
		tbar.max_value = float(sd.transit_days_total)
		tbar.value = float(sd.transit_days_total - sd.transit_days_remaining)
		tbar.show_percentage = false
		block.add_child(tbar)
		var sub: Label = Label.new()
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
		sub.text = "Transit: %d / %d days" % [sd.transit_days_remaining, sd.transit_days_total]
		block.add_child(sub)
	return block


func _format_number(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var i: int = s.length() - 1
	var count: int = 0
	while i >= 0:
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
		i -= 1
	return out
