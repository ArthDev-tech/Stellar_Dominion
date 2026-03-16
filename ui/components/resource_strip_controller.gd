class_name ResourceStripController
extends RefCounted
## Builds and updates the resource strip in the top bar. Shared by GameScene and SolarSystemView.

var _line1: HBoxContainer
var _line2: HBoxContainer
var _top_bar_vbox: VBoxContainer
var _date_label: Label
var _ui_theme_func: Callable
var _config_func: Callable  ## Returns GameplayConfig; used for resource_icon_set
var _resource_labels: Array[Label] = []

signal resource_row_entered(res_type: int)
signal resource_row_exited()


func setup(line1: HBoxContainer, line2: HBoxContainer, top_bar_vbox: VBoxContainer, date_label: Label, ui_theme_func: Callable, config_func: Callable = Callable()) -> void:
	_line1 = line1
	_line2 = line2
	_top_bar_vbox = top_bar_vbox
	_date_label = date_label
	_ui_theme_func = ui_theme_func
	_config_func = config_func


func build_resource_strip() -> void:
	if _line1 == null or _line2 == null:
		return
	for c in _line1.get_children():
		c.queue_free()
	for c in _line2.get_children():
		c.queue_free()
	_resource_labels.clear()
	_resource_labels.resize(GameResources.ResourceType.LAST)
	for i in _resource_labels.size():
		_resource_labels[i] = null
	var icon_script: GDScript = preload("res://ui/components/resource_icon.gd") as GDScript
	for section_dict in GameResources.RESOURCE_SECTIONS_ROW1:
		_add_section_block(_line1, section_dict, icon_script)
	for section_dict in GameResources.RESOURCE_SECTIONS_ROW2:
		_add_section_block(_line2, section_dict, icon_script)


func update_resource_display() -> void:
	if _date_label != null:
		var year: int = int(GameState.game_date_months / 12) + 1
		var month_in_year: int = GameState.game_date_months % 12 + 1
		_date_label.text = "Year %d, Month %d, Day %d" % [year, month_in_year, GameState.day_of_month + 1]
	if EmpireManager == null or _resource_labels.size() != GameResources.ResourceType.LAST:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var r: GameResources = player_emp.resources
	var th: UIThemeOverrides = _ui_theme_func.call() if _ui_theme_func.is_valid() else null
	var default_color: Color = th.strip_value_font_color if th != null else Color(0.95, 0.95, 1, 1)
	var positive_color: Color = th.strip_value_font_color_positive if th != null else Color(1.0, 0.65, 0.2, 1.0)
	for res_type in range(GameResources.ResourceType.LAST):
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(res_type, "?")
		var amt: float = r.get_amount(res_type as GameResources.ResourceType)
		var inc: float = r.income_per_month.get(res_type, 0.0)
		var text: String
		if res_type == GameResources.ResourceType.MANPOWER and EconomyManager != null:
			var cap: float = EconomyManager.get_manpower_cap(player_emp)
			if abs(inc) >= 0.01:
				text = "%s %d/%d %+.0f" % [short, int(amt), int(cap), inc]
			else:
				text = "%s %d/%d" % [short, int(amt), int(cap)]
		elif abs(inc) >= 0.01:
			text = "%s %d %+.0f" % [short, int(amt), inc]
		else:
			text = "%s %d" % [short, int(amt)]
		if res_type < _resource_labels.size() and _resource_labels[res_type] != null:
			var lbl: Label = _resource_labels[res_type]
			lbl.text = text
			lbl.add_theme_color_override("font_color", positive_color if inc >= 0.01 else default_color)
	if _top_bar_vbox != null:
		_redraw_resource_icons(_top_bar_vbox)


func _add_section_block(parent_row: HBoxContainer, section_dict: Dictionary, icon_script: GDScript) -> void:
	var th: UIThemeOverrides = _ui_theme_func.call() if _ui_theme_func.is_valid() else null
	var icon_set: ResourceIconSet = null
	if _config_func.is_valid():
		var cfg: GameplayConfig = _config_func.call()
		if cfg != null:
			icon_set = cfg.resource_icon_set
	var icon_sz: int = th.strip_icon_size if th != null else 27
	var section_name: String = section_dict.get("name", "")
	var section_bg: Color = _section_bg_color(th, section_name)
	var section_panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = section_bg
	style.border_color = th.strip_panel_border_color if th != null else Color(0.3, 0.4, 0.55, 0.9)
	style.set_border_width_all(th.strip_panel_border_width if th != null else 1)
	style.set_corner_radius_all(th.strip_panel_corner_radius if th != null else 3)
	style.set_content_margin_all(th.strip_panel_content_margin if th != null else 10)
	section_panel.add_theme_stylebox_override("panel", style)
	var section_vbox: VBoxContainer = VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", 2)
	var items_hbox: HBoxContainer = HBoxContainer.new()
	items_hbox.add_theme_constant_override("separation", th.strip_separation if th != null else 8)
	var types: Array = section_dict.get("types", [])
	for res_type in types:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_on_row_entered.bind(res_type))
		row.mouse_exited.connect(_on_row_exited)
		row.add_theme_constant_override("separation", th.panel_vbox_separation if th != null else 4)
		var icon: Control = Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_script(icon_script)
		icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon.size = Vector2(icon_sz, icon_sz)
		icon.set_meta("resource_type", res_type)
		row.add_child(icon)
		var tex: Texture2D = _load_icon_for_type(icon_set, res_type as int)
		icon.resource_type = res_type
		icon.icon_texture = tex
		var lbl: Label = Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", th.strip_value_font_size if th != null else 20)
		lbl.add_theme_color_override("font_color", th.strip_value_font_color if th != null else Color(0.95, 0.95, 1, 1))
		var rt: int = res_type as int
		if rt >= 0 and rt < _resource_labels.size():
			_resource_labels[rt] = lbl
		row.add_child(lbl)
		items_hbox.add_child(row)
	section_vbox.add_child(items_hbox)
	section_panel.add_child(section_vbox)
	parent_row.add_child(section_panel)


func _section_bg_color(th: UIThemeOverrides, section_name: String) -> Color:
	var fallback: Color = Color(0.14, 0.16, 0.22, 0.92)
	if th == null:
		return fallback
	match section_name:
		"Raw":
			return th.strip_panel_bg_raw
		"Refined":
			return th.strip_panel_bg_refined
		"Strategic":
			return th.strip_panel_bg_strategic
		"Abstract":
			return th.strip_panel_bg_abstract
		_:
			return th.strip_panel_bg_color


func _load_icon_for_type(icon_set: ResourceIconSet, res_type: int) -> Texture2D:
	if icon_set == null or res_type < 0 or res_type >= icon_set.icon_paths.size():
		return null
	var path: String = (icon_set.icon_paths[res_type] as String).strip_edges()
	if path.is_empty():
		return null
	if not path.begins_with("res://"):
		path = icon_set.base_path.path_join(path)
	var tex: Texture2D = load(path) as Texture2D
	return tex


func _on_row_entered(res_type: int) -> void:
	resource_row_entered.emit(res_type)


func _on_row_exited() -> void:
	resource_row_exited.emit()


func _redraw_resource_icons(node: Node) -> void:
	if node is Control and node.get_meta("resource_type", -999) != -999:
		(node as Control).queue_redraw()
	for c in node.get_children():
		_redraw_resource_icons(c)
