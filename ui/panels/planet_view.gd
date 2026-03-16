extends DraggableOverlay
## Planet view: colony stats, build districts and buildings.
## Reads GameState.selected_colony_system_id, selected_colony_planet_index, planet_view_return_scene.
## When run as overlay, Back emits closed and removes overlay; else Back changes scene.

signal closed
signal colony_updated

@onready var title_label: Label = $Margin/MainHBox/ScrollContainer/VBox/TitleBarPanel/HeaderVBox/TitleBar/TitleLabel
@onready var back_button: Button = $Margin/MainHBox/ScrollContainer/VBox/TitleBarPanel/HeaderVBox/TitleBar/BackButton
@onready var subtitle_label: Label = $Margin/MainHBox/ScrollContainer/VBox/TitleBarPanel/HeaderVBox/SubtitleLabel
@onready var summary_label: Label = $Margin/MainHBox/ScrollContainer/VBox/SummaryLabel
@onready var districts_container: VBoxContainer = $Margin/MainHBox/ScrollContainer/VBox/TabContainer/Management/DistrictsSection/DistrictsContainer
@onready var buildings_container: VBoxContainer = $Margin/MainHBox/ScrollContainer/VBox/TabContainer/Management/BuildingsSection/BuildingsContainer
@onready var tab_container: TabContainer = $Margin/MainHBox/ScrollContainer/VBox/TabContainer
@onready var economy_jobs_container: VBoxContainer = $Margin/MainHBox/ScrollContainer/VBox/TabContainer/Economy/EconomyScroll/EconomyJobsContainer

const BUILD_OPTIONS_WINDOW_SCENE: PackedScene = preload("res://ui/panels/build_options_window.tscn")
const BUILD_OPTIONS_WINDOW_GAP: int = 16

var _colony: Colony
var _empire: Empire
var _planet: Planet
var _system_name: String = ""
var _buildable_building_ids: Array = []   # planetary only
var _buildable_orbital_ids: Array = []    # orbital only
var _economy_tab_index: int = 1


func _ready() -> void:
	super._ready()
	_style_top_bar()
	back_button.pressed.connect(_on_back_pressed)
	for i in range(tab_container.get_child_count()):
		if tab_container.get_child(i).name == "Economy":
			_economy_tab_index = i
			var economy_tab: Control = tab_container.get_child(i) as Control
			if economy_tab != null:
				economy_tab.size_flags_vertical = Control.SIZE_FILL
			break
	tab_container.tab_selected.connect(_on_tab_selected)
	var system_id: int = GameState.selected_colony_system_id
	var planet_index: int = GameState.selected_colony_planet_index
	if system_id < 0 or planet_index < 0 or EmpireManager == null or GalaxyManager == null:
		title_label.text = "No colony selected"
		summary_label.text = "Return to galaxy or solar system and select a colony."
		return
	var emp: Empire = EmpireManager.get_player_empire()
	if emp == null:
		title_label.text = "No empire"
		return
	_colony = emp.get_colony(system_id, planet_index)
	if _colony == null:
		title_label.text = "Colony not found"
		summary_label.text = "No player colony at this location."
		return
	var sys: StarSystem = GalaxyManager.get_system(system_id)
	if sys == null or planet_index >= sys.planets.size():
		title_label.text = "Invalid system"
		return
	_planet = sys.planets[planet_index]
	_empire = emp
	_system_name = sys.name_key
	title_label.text = _planet.name_key + " — " + _system_name
	_set_planet_subtitle()
	_refresh_ui()


func _set_planet_subtitle() -> void:
	if subtitle_label == null or _planet == null:
		return
	var type_name: String = Planet.PlanetType.keys()[_planet.type] if _planet.type >= 0 else "?"
	var line: String = "Type: %s  |  Size: %d  |  Habitability: %.0f%%  |  Orbit: %.0f" % [type_name, _planet.size, _planet.habitability * 100.0, _planet.orbit_radius]
	var deposit_line: String = _format_planet_deposits(_planet.deposits)
	if deposit_line != "":
		line += "  |  Deposits: " + deposit_line
	subtitle_label.text = line


func _format_planet_deposits(deposits: Array) -> String:
	if deposits.is_empty():
		return ""
	var parts: PackedStringArray = []
	for d in deposits:
		var rt: int = d.get("resource_type", 0)
		var amt: float = d.get("amount", 0.0)
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		parts.append("%s %.0f" % [short, amt])
	return "  ".join(parts)


func _style_top_bar() -> void:
	var bar: PanelContainer = get_node_or_null("Margin/MainHBox/ScrollContainer/VBox/TitleBarPanel") as PanelContainer
	if bar == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.24, 0.35, 1.0)
	style.border_color = Color(0.4, 0.45, 0.6, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", style)


func _refresh_ui() -> void:
	if _colony == null or _empire == null or _planet == null:
		return
	var max_d: int = _colony.get_max_districts(_planet)
	var total_d: int = _colony.get_total_districts()
	var slots: int = _colony.get_building_slots()
	var planetary_used: int = _colony.buildings.size()
	_colony._ensure_city_specializations_synced()
	for spec_list in _colony.city_specialization_buildings:
		if spec_list is Array:
			planetary_used += (spec_list as Array).size()
	var housing: int = _colony.get_total_housing()
	var max_pop: int = _colony.get_max_population(_planet)
	var civilians: int = _colony.get_civilian_count()
	var orbital_slots: int = _colony.get_orbital_slots()
	summary_label.text = "Pops: %d / %d  |  Employed: %d  |  Civilians: %d  |  Growth: %.0f / 100  |  Housing: %d  |  Districts: %d / %d  |  Planetary: %d / %d  |  Orbital: %d / %d" % [
		_colony.pop_count,
		max_pop,
		_colony.pop_count - civilians,
		civilians,
		_colony.growth_progress,
		housing,
		total_d,
		max_d,
		planetary_used,
		slots,
		_colony.orbital_buildings.size(),
		orbital_slots
	]
	_populate_districts()
	_populate_buildings()
	_refresh_economy_tab()


const DISTRICT_SLOT_SIZE: int = 28

func _populate_districts() -> void:
	for c in districts_container.get_children():
		c.queue_free()
	var d_data: Array = _load_json_array(ProjectPaths.DATA_DISTRICTS)
	var max_d: int = _colony.get_max_districts(_planet)
	var total_d: int = _colony.get_total_districts()
	for d in d_data:
		var id_str: String = d.get("id", "")
		var name_key: String = d.get("name_key", id_str)
		var count: int = _colony.district_counts.get(id_str, 0)
		var cost_json: Dictionary = d.get("cost", {})
		var cost: Dictionary = _cost_dict_from_json(cost_json)
		var cost_str: String = _format_cost(cost)
		# Row: label (Name: count / max), slot strip, Build button
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var top: HBoxContainer = HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var lbl: Label = Label.new()
		lbl.text = "%s: %d / %d" % [name_key, count, max_d]
		lbl.custom_minimum_size.x = 180.0
		top.add_child(lbl)
		var slots_h: HBoxContainer = HBoxContainer.new()
		slots_h.add_theme_constant_override("separation", 2)
		for i in range(max_d):
			var slot: Button = Button.new()
			slot.custom_minimum_size = Vector2(DISTRICT_SLOT_SIZE, DISTRICT_SLOT_SIZE)
			slot.flat = true
			if i < count:
				slot.text = id_str.substr(0, 1).to_upper()
				slot.disabled = true
			else:
				slot.text = "+"
				slot.disabled = true
			slots_h.add_child(slot)
		top.add_child(slots_h)
		var build_btn: Button = Button.new()
		var at_cap: bool = total_d >= max_d
		var can_afford: bool = _empire.resources.can_afford(cost)
		build_btn.text = "Build (%s)" % cost_str if cost_str != "" else "Build"
		build_btn.disabled = at_cap or not can_afford
		build_btn.pressed.connect(_on_build_district.bind(id_str))
		top.add_child(build_btn)
		row.add_child(top)
		# City: 3 planet-wide specialization slots (one row: [Specialize] then 3 slot cells)
		if id_str == "city" and count > 0:
			_colony._ensure_city_specializations_synced()
			var spec_row: HBoxContainer = HBoxContainer.new()
			spec_row.add_theme_constant_override("separation", 8)
			var spec_btn: Button = Button.new()
			spec_btn.custom_minimum_size = Vector2(100, 32)
			spec_btn.text = "Specialize"
			spec_btn.pressed.connect(_on_specialize_city_pressed)
			spec_row.add_child(spec_btn)
			for slot_idx in range(_colony.city_specializations.size()):
				var spec_id: String = _colony.city_specializations[slot_idx] as String
				if spec_id.length() > 0:
					var spec_name: String = _get_specialization_name(spec_id)
					var cell: Button = Button.new()
					cell.custom_minimum_size = Vector2(100, 32)
					cell.text = spec_name
					cell.flat = true
					cell.disabled = true
					spec_row.add_child(cell)
				else:
					var slot_btn: Button = Button.new()
					slot_btn.custom_minimum_size = Vector2(100, 32)
					slot_btn.text = "—"
					slot_btn.flat = true
					slot_btn.disabled = true
					spec_row.add_child(slot_btn)
			row.add_child(spec_row)
			# Under each filled specialization: 4 building slots (allowed_buildings only)
			for slot_idx in range(_colony.city_specializations.size()):
				var spec_id: String = _colony.city_specializations[slot_idx] as String
				if spec_id.length() > 0:
					_add_city_spec_building_slots(row, slot_idx, spec_id)
		# Resource districts (energy, mining, farming): building slots directly under this section
		if id_str == "energy" or id_str == "mining" or id_str == "farming":
			_add_amplifier_slots_under_district(row, id_str)
		districts_container.add_child(row)


func _add_amplifier_slots_under_district(row: VBoxContainer, district_type: String) -> void:
	var specialized: bool = _colony.district_amplifier_specialized.get(district_type, false)
	var slots: int = _colony.get_district_amplifier_slots(district_type)
	var b_data: Array = Colony.get_all_building_defs()
	var name_by_id: Dictionary = {}
	var def_by_id: Dictionary = {}
	for b in b_data:
		var id_str: String = b.get("id", "")
		name_by_id[id_str] = b.get("name_key", "")
		def_by_id[id_str] = b
	var list: Array = _colony.district_amplifier_buildings.get(district_type, [])
	var sub_label: Label = Label.new()
	if specialized:
		sub_label.text = "Building slots (+20%% output per building, %d slots)" % slots
	else:
		sub_label.text = "Specialize to unlock 4 building slots"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	row.add_child(sub_label)
	var amp_row: HBoxContainer = HBoxContainer.new()
	amp_row.add_theme_constant_override("separation", 8)
	if not specialized:
		var spec_btn: Button = Button.new()
		spec_btn.custom_minimum_size = Vector2(120, 48)
		spec_btn.text = "Specialize"
		spec_btn.pressed.connect(_on_resource_district_specialize_pressed.bind(district_type))
		amp_row.add_child(spec_btn)
	else:
		for i in range(slots):
			if i < list.size():
				var bid: String = list[i] if list[i] is String else str(list[i])
				var cell: Button = Button.new()
				cell.custom_minimum_size = Vector2(120, 48)
				cell.text = name_by_id.get(bid, bid)
				cell.flat = true
				cell.disabled = true
				_apply_building_icon(cell, def_by_id.get(bid, {}))
				amp_row.add_child(cell)
			else:
				var build_btn: Button = Button.new()
				build_btn.custom_minimum_size = Vector2(120, 48)
				build_btn.text = "+ Build"
				build_btn.pressed.connect(_on_amplifier_build_pressed.bind(district_type))
				amp_row.add_child(build_btn)
	row.add_child(amp_row)


func _add_city_spec_building_slots(row: VBoxContainer, slot_idx: int, spec_id: String) -> void:
	var spec_name: String = _get_specialization_name(spec_id)
	var b_data: Array = Colony.get_all_building_defs()
	var name_by_id: Dictionary = {}
	var def_by_id: Dictionary = {}
	for b in b_data:
		var id_str: String = b.get("id", "")
		name_by_id[id_str] = b.get("name_key", "")
		def_by_id[id_str] = b
	var list: Array = _colony.city_specialization_buildings[slot_idx] if slot_idx < _colony.city_specialization_buildings.size() else []
	var sub_label: Label = Label.new()
	sub_label.text = "%s — Building slots (4)" % spec_name
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	row.add_child(sub_label)
	var slot_row: HBoxContainer = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	for i in range(4):
		if i < list.size():
			var bid: String = list[i] if list[i] is String else str(list[i])
			var cell: Button = Button.new()
			cell.custom_minimum_size = Vector2(120, 48)
			cell.text = name_by_id.get(bid, bid)
			cell.flat = true
			cell.disabled = true
			_apply_building_icon(cell, def_by_id.get(bid, {}))
			slot_row.add_child(cell)
		else:
			var build_btn: Button = Button.new()
			build_btn.custom_minimum_size = Vector2(120, 48)
			build_btn.text = "+ Build"
			build_btn.pressed.connect(_on_city_spec_build_pressed.bind(slot_idx))
			slot_row.add_child(build_btn)
	row.add_child(slot_row)


func _populate_buildings() -> void:
	for c in buildings_container.get_children():
		c.queue_free()
	var b_data: Array = Colony.get_all_building_defs()
	var name_by_id: Dictionary = {}
	var def_by_id: Dictionary = {}
	for b in b_data:
		var id_str: String = b.get("id", "")
		name_by_id[id_str] = b.get("name_key", "")
		def_by_id[id_str] = b
	_buildable_building_ids.clear()
	_buildable_orbital_ids.clear()
	for b in b_data:
		var id_str: String = b.get("id", "")
		if id_str == "capital":
			continue
		if b.get("slot_type", "planetary") == "orbital":
			_buildable_orbital_ids.append(id_str)
		elif b.get("slot_type", "planetary") != "district_amplifier":
			_buildable_building_ids.append(id_str)
	# Planetary complexes (base 9 slots only; spec slots are under each city specialization)
	const BASE_SLOTS: int = 9
	var p_header: Label = Label.new()
	p_header.text = "Planetary complexes (%d slots)" % BASE_SLOTS
	p_header.add_theme_font_size_override("font_size", 18)
	buildings_container.add_child(p_header)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(BASE_SLOTS):
		if i < _colony.buildings.size():
			var bid: String = _colony.buildings[i]
			var cell: Button = Button.new()
			cell.custom_minimum_size = Vector2(120, 56)
			cell.text = name_by_id.get(bid, bid)
			cell.flat = true
			cell.disabled = true
			_apply_building_icon(cell, def_by_id.get(bid, {}))
			grid.add_child(cell)
		else:
			var build_btn: Button = Button.new()
			build_btn.custom_minimum_size = Vector2(120, 56)
			build_btn.text = "+ Build"
			build_btn.pressed.connect(_on_empty_slot_build_pressed.bind(build_btn))
			grid.add_child(build_btn)
	buildings_container.add_child(grid)
	# Orbital section (separate slots)
	var orb_slots: int = _colony.get_orbital_slots()
	var o_header: Label = Label.new()
	o_header.text = "Orbital (%d slots)" % orb_slots
	o_header.add_theme_font_size_override("font_size", 18)
	buildings_container.add_child(o_header)
	var orb_grid: GridContainer = GridContainer.new()
	orb_grid.columns = 3
	orb_grid.add_theme_constant_override("h_separation", 8)
	orb_grid.add_theme_constant_override("v_separation", 8)
	for i in range(orb_slots):
		if i < _colony.orbital_buildings.size():
			var bid: String = _colony.orbital_buildings[i]
			var cell: Button = Button.new()
			cell.custom_minimum_size = Vector2(120, 56)
			cell.text = name_by_id.get(bid, bid)
			cell.flat = true
			cell.disabled = true
			_apply_building_icon(cell, def_by_id.get(bid, {}))
			orb_grid.add_child(cell)
		else:
			var build_btn: Button = Button.new()
			build_btn.custom_minimum_size = Vector2(120, 56)
			build_btn.text = "+ Build"
			build_btn.pressed.connect(_on_orbital_empty_slot_build_pressed.bind(build_btn))
			orb_grid.add_child(build_btn)
	buildings_container.add_child(orb_grid)


func _refresh_economy_tab() -> void:
	if economy_jobs_container == null:
		push_warning("PlanetView: Economy jobs container is null.")
		return
	for c in economy_jobs_container.get_children():
		economy_jobs_container.remove_child(c)
		c.queue_free()
	if _colony == null:
		var msg: Label = Label.new()
		msg.text = "No colony selected."
		msg.add_theme_font_size_override("font_size", 14)
		economy_jobs_container.add_child(msg)
		_force_economy_tab_layout()
		return
	var filled: Dictionary = _colony.assign_pops_to_jobs()
	var slots: Dictionary = _colony.get_job_slots()
	var job_ids: Array = []
	for jid in slots:
		if slots[jid] > 0 and jid not in job_ids:
			job_ids.append(jid)
	job_ids.sort()
	if job_ids.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1))
		empty_lbl.text = "No job slots on this colony. Build districts and buildings to create jobs."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		economy_jobs_container.add_child(empty_lbl)
		if slots.size() > 0:
			var debug_lbl: Label = Label.new()
			debug_lbl.add_theme_font_size_override("font_size", 12)
			debug_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
			debug_lbl.text = "Debug: slots has %d job types (all zero?). Keys: %s" % [slots.size(), str(slots.keys())]
			economy_jobs_container.add_child(debug_lbl)
		else:
			var debug_lbl: Label = Label.new()
			debug_lbl.add_theme_font_size_override("font_size", 12)
			debug_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
			debug_lbl.text = "Debug: get_job_slots() returned empty. Check console for Colony warnings."
			economy_jobs_container.add_child(debug_lbl)
		_force_economy_tab_layout()
		return
	var employed: int = _colony.get_employed_count()
	var unfilled: int = 0
	for jid in job_ids:
		unfilled += maxi(0, slots.get(jid, 0) - filled.get(jid, 0))
	var summary_lbl: Label = Label.new()
	summary_lbl.add_theme_font_size_override("font_size", 14)
	summary_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 1, 1))
	summary_lbl.text = "Employed: %d  |  Unfilled slots: %d  |  Job types: %d" % [employed, unfilled, job_ids.size()]
	economy_jobs_container.add_child(summary_lbl)
	for job_id in job_ids:
		var def: Dictionary = _colony.get_job_definition_for_display(job_id)
		var name_key: String = def.get("name_key", job_id)
		var total_slots: int = slots.get(job_id, 0)
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.2, 0.28, 0.85)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		var title_lbl: Label = Label.new()
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
		title_lbl.text = name_key
		vbox.add_child(title_lbl)
		var count_lbl: Label = Label.new()
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1))
		count_lbl.text = "%d available" % total_slots
		vbox.add_child(count_lbl)
		panel.add_child(vbox)
		economy_jobs_container.add_child(panel)
	_force_economy_tab_layout()


func _force_economy_tab_layout() -> void:
	economy_jobs_container.queue_sort()
	var scroll: Node = economy_jobs_container.get_parent()
	if scroll is Control:
		(scroll as Control).queue_sort()


func _on_tab_selected(tab_idx: int) -> void:
	if tab_idx == _economy_tab_index:
		call_deferred("_refresh_economy_tab")


func _on_amplifier_build_pressed(district_type: String) -> void:
	var b_data: Array = Colony.get_all_building_defs()
	var ids: Array = []
	for b in b_data:
		if b.get("slot_type", "") == "district_amplifier" and b.get("district_type", "") == district_type:
			ids.append(b.get("id", ""))
	var type_names: Dictionary = {"energy": "Generator", "mining": "Mining", "farming": "Agriculture"}
	var title: String = "%s district building" % type_names.get(district_type, district_type)
	_open_build_options_window(title, ids, _options_for_amplifier_building.bind(district_type), _on_option_amplifier_pressed.bind(district_type))


func _open_build_options_window(title: String, ids: Array, get_label: Callable, on_select: Callable) -> void:
	var win: PanelContainer = BUILD_OPTIONS_WINDOW_SCENE.instantiate()
	var parent: Control = get_parent() as Control
	if parent == null:
		return
	parent.add_child(win)
	var pv_rect: Rect2 = get_global_rect()
	win.custom_minimum_size = Vector2(440, pv_rect.size.y)
	win.position = parent.get_global_transform_with_canvas().affine_inverse() * (pv_rect.position + Vector2(pv_rect.size.x + BUILD_OPTIONS_WINDOW_GAP, 0))
	win.open(title, ids, get_label, on_select)
	# Style the window panel to match
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.2, 0.28, 0.98)
	panel_style.border_color = Color(0.35, 0.4, 0.55, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(12)
	win.add_theme_stylebox_override("panel", panel_style)


func _options_for_planetary_building(bid: String) -> String:
	var b_data: Array = Colony.get_all_building_defs()
	for b in b_data:
		if b.get("id", "") == bid:
			var name_key: String = b.get("name_key", bid)
			var cost: Dictionary = _cost_dict_from_json(b.get("cost", {}))
			var cost_str: String = _format_cost(cost)
			return name_key if cost_str.is_empty() else "%s (%s)" % [name_key, cost_str]
	return bid


func _options_for_orbital_building(bid: String) -> String:
	return _options_for_planetary_building(bid)


func _options_for_amplifier_building(_district_type: String, bid: String) -> String:
	return _options_for_planetary_building(bid)


func _options_for_specialization(spec_id: String) -> String:
	var s_data: Array = _load_json_array(ProjectPaths.DATA_CITY_SPECIALIZATIONS)
	for s in s_data:
		if s.get("id", "") == spec_id:
			var name_key: String = s.get("name_key", spec_id)
			var cost: Dictionary = _cost_dict_from_json(s.get("cost", {}))
			var cost_str: String = _format_cost(cost)
			return name_key if cost_str.is_empty() else "%s (%s)" % [name_key, cost_str]
	return spec_id


func _on_option_build_planetary_pressed(building_id: String) -> void:
	_on_build_building(building_id)


func _on_option_build_orbital_pressed(building_id: String) -> void:
	if _colony.add_orbital_building(building_id, _empire):
		if building_id == "orbital_station":
			var station_name: String = _planet.name_key + " Station"
			_empire.ensure_station_at_colony(_colony.system_id, _colony.planet_index, station_name)
			colony_updated.emit()
		_refresh_ui()


func _on_option_amplifier_pressed(building_id: String, district_type: String) -> void:
	if _colony.add_district_amplifier_building(district_type, building_id, _empire):
		_refresh_ui()


func _on_option_specialize_pressed(spec_id: String) -> void:
	if _colony.add_city_specialization(0, spec_id, _empire):
		_refresh_ui()


func _apply_building_icon(button: Button, def: Dictionary) -> void:
	var icon_path: String = def.get("icon", "")
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex != null:
		button.icon = tex
		button.expand_icon = true


func _on_empty_slot_build_pressed(_button: Button) -> void:
	if _colony.buildings.size() >= 9:
		return
	_open_build_options_window("Planetary building", _buildable_building_ids, _options_for_planetary_building, _on_option_build_planetary_pressed)


func _on_city_spec_build_pressed(slot_idx: int) -> void:
	var s_data: Array = _load_json_array(ProjectPaths.DATA_CITY_SPECIALIZATIONS)
	var spec_id: String = _colony.city_specializations[slot_idx] as String
	var ids: Array = []
	for s in s_data:
		if s.get("id", "") == spec_id:
			ids = s.get("allowed_buildings", [])
			break
	var spec_name: String = _get_specialization_name(spec_id)
	_open_build_options_window("%s building" % spec_name, ids, _options_for_planetary_building, _on_option_city_spec_build_pressed.bind(slot_idx))


func _on_option_city_spec_build_pressed(building_id: String, slot_idx: int) -> void:
	if _colony.add_city_specialization_building(slot_idx, building_id, _empire):
		_refresh_ui()


func _on_orbital_empty_slot_build_pressed(_button: Button) -> void:
	if _colony.orbital_buildings.size() >= _colony.get_orbital_slots():
		return
	_open_build_options_window("Orbital building", _buildable_orbital_ids, _options_for_orbital_building, _on_option_build_orbital_pressed)


func _get_specialization_name(spec_id: String) -> String:
	var s_data: Array = _load_json_array(ProjectPaths.DATA_CITY_SPECIALIZATIONS)
	for s in s_data:
		if s.get("id", "") == spec_id:
			return s.get("name_key", spec_id)
	return spec_id


func _on_specialize_city_pressed() -> void:
	var s_data: Array = _load_json_array(ProjectPaths.DATA_CITY_SPECIALIZATIONS)
	var ids: Array = []
	for s in s_data:
		ids.append(s.get("id", ""))
	_open_build_options_window("Specialize district", ids, _options_for_specialization, _on_option_specialize_pressed)


func _on_resource_district_specialize_pressed(district_type: String) -> void:
	if _colony.add_resource_district_specialization(district_type, _empire):
		_refresh_ui()


func _on_build_district(district_id: String) -> void:
	if _colony.add_district(district_id, _empire, _planet):
		_refresh_ui()


func _on_build_building(building_id: String) -> void:
	if _colony.add_building(building_id, _empire):
		_refresh_ui()


func _on_back_pressed() -> void:
	if get_tree().current_scene != self:
		closed.emit()
	else:
		var scene: String = GameState.planet_view_return_scene
		if scene.is_empty():
			scene = ProjectPaths.SCENE_GAME_SCENE
		get_tree().change_scene_to_file(scene)


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json: JSON = JSON.new()
	var err: Error = json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return []
	return json.data if json.data is Array else []


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
		var name_str: String = GameResources.RESOURCE_NAMES.get(rt, "?")
		parts.append("%d %s" % [int(cost[rt]), name_str])
	return ", ".join(parts)
