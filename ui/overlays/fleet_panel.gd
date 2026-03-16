extends DraggablePanel
## Fleet selection panel: shows fleet composition when one fleet selected, summary when multiple.

@export_group("Panel")
@export var panel_color: Color = Color(0.08, 0.12, 0.18, 0.92)
@export var max_visible_ships_before_scroll: int = 8

var _fleet_name_label: Label
var _fleet_power_label: Label
var _ship_list_container: VBoxContainer
var _total_count_label: Label
var _scroll_container: ScrollContainer


func _ready() -> void:
	super._ready()
	var title_lbl: Label = get_node_or_null("TitleBar/TitleLabel") as Label
	if title_lbl != null:
		title_lbl.text = "Fleet"
	_fleet_name_label = get_node_or_null("MarginContainer/VBoxContainer/FleetNameLabel") as Label
	_fleet_power_label = get_node_or_null("MarginContainer/VBoxContainer/FleetPowerLabel") as Label
	_scroll_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer") as ScrollContainer
	_ship_list_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/ShipListContainer") as VBoxContainer
	_total_count_label = get_node_or_null("MarginContainer/VBoxContainer/TotalCountLabel") as Label
	_add_panel_style()
	visible = false
	if SelectionManager != null:
		SelectionManager.selection_changed.connect(_on_selection_changed)
		_on_selection_changed(SelectionManager.selected_ships)


func _add_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.4, 0.55, 0.6)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


func _on_selection_changed(_ships: Array) -> void:
	if SelectionManager == null:
		visible = false
		return
	var nodes: Array = SelectionManager.selected_ships
	if nodes.is_empty():
		visible = false
		return
	var fleet_data_list: Array[FleetData] = []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var fd: FleetData = null
		if "fleet_data" in n:
			fd = n.fleet_data
		if fd == null and n.has_meta("fleet_data"):
			fd = n.get_meta("fleet_data") as FleetData
		if fd != null:
			fleet_data_list.append(fd)
	if fleet_data_list.is_empty():
		visible = false
		return
	visible = true
	if fleet_data_list.size() == 1:
		_show_single_fleet(fleet_data_list[0])
	else:
		_show_multi_fleet_summary(fleet_data_list)


func _show_single_fleet(fd: FleetData) -> void:
	if _fleet_name_label != null:
		_fleet_name_label.text = fd.fleet_name if fd.fleet_name != "" else "Fleet"
	if _fleet_power_label != null:
		var power: float = fd.get_total_power()
		_fleet_power_label.text = "Combat Power: %s" % _format_number(int(power))
	if _ship_list_container != null:
		for c in _ship_list_container.get_children():
			c.queue_free()
		for s in fd.ships:
			if s == null:
				continue
			var row: HBoxContainer = _make_ship_row(s)
			_ship_list_container.add_child(row)
	if _scroll_container != null:
		var max_h: float = max_visible_ships_before_scroll * 22.0
		_scroll_container.custom_minimum_size.y = minf(max_h, fd.ships.size() * 22.0)
	if _total_count_label != null:
		_total_count_label.text = "%d ships" % fd.ships.size()


func _make_ship_row(ship_data: ShipData) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# Class icon (small colored shape)
	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	var class_color: Color = Color(0.8, 0.8, 0.7)
	match ship_data.ship_class:
		"science":
			class_color = Color(0.4, 0.7, 1.0)
		"construction", "constructor":
			class_color = Color(0.95, 0.85, 0.3)
		"military", _:
			class_color = Color(0.95, 0.35, 0.3)
	icon.color = class_color
	row.add_child(icon)
	# Ship name
	var name_lbl: Label = Label.new()
	name_lbl.text = ship_data.ship_name if ship_data.ship_name != "" else ship_data.ship_class
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)
	# Hull bar
	var hull_max: float = ship_data.hull_max if ship_data.hull_max > 0 else 1.0
	var ratio: float = clampf(ship_data.hull_current / hull_max, 0.0, 1.0)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 12)
	bar.max_value = 1.0
	bar.value = ratio
	bar.show_percentage = false
	row.add_child(bar)
	return row


func _show_multi_fleet_summary(fleet_data_list: Array[FleetData]) -> void:
	if _fleet_name_label != null:
		_fleet_name_label.text = "Multiple fleets"
	var total_power: float = 0.0
	var total_ships: int = 0
	for fd in fleet_data_list:
		if fd != null:
			total_power += fd.get_total_power()
			total_ships += fd.ships.size()
	if _fleet_power_label != null:
		_fleet_power_label.text = "Combined power: %s" % _format_number(int(total_power))
	if _ship_list_container != null:
		for c in _ship_list_container.get_children():
			c.queue_free()
	if _total_count_label != null:
		_total_count_label.text = "%d fleets, %d ships" % [fleet_data_list.size(), total_ships]


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
