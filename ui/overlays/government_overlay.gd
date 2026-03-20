extends Control
## Full-screen political management: key holder cards in a row, policy panel left, connection lines, detail panel right.
## Emits closed when Close is pressed.

signal closed
signal satisfy_demand_requested(holder_id: StringName)
signal view_loyalty_history_requested(holder_id: StringName)
signal lock_policy_requested(policy_id: StringName)

## policy_id / holder_id -> Vector2 global (anchor dot position)
var policy_dot_centers: Dictionary = {}
var holder_dot_centers: Dictionary = {}
## { "type": "holder"|"policy", "id": StringName } or empty
var selected_item: Dictionary = {}

var _connection_canvas: Control = null
var _connection_canvas_dirty: bool = false
var _policy_sliders: Dictionary = {}
var _policy_dots: Dictionary = {}
var _policy_wrappers: Dictionary = {}
var _holder_cards: Dictionary = {}
var _holder_dots: Dictionary = {}
var _header_title: Label = null
var _stability_bar: ProgressBar = null
var _categories_container: HBoxContainer = null
var _keys_row: HBoxContainer = null
var _routing_zone: Control = null
var _canvas_area: Control = null
var _detail_panel: PanelContainer = null
var _detail_title: Label = null
var _detail_subtitle: Label = null
var _detail_desc: Label = null
var _detail_demand: PanelContainer = null
var _detail_demand_label: Label = null
var _detail_connections: VBoxContainer = null
var _detail_actions: VBoxContainer = null

const KEYS_ROW_HEIGHT: int = 120
const ROUTING_ZONE_HEIGHT: int = 80
const CATEGORY_COLUMN_GUTTER: int = 12
const DETAIL_PANEL_WIDTH: int = 220
const CATEGORY_BORDER_WIDTH: float = 0.5
const CATEGORY_MAX_POLICIES_BEFORE_SCROLL: int = 5
const KEY_CARD_MIN_WIDTH: int = 140
const KEY_CARD_MAX_WIDTH: int = 160
const COLOR_GREEN: Color = Color(0.388, 0.6, 0.133)
const COLOR_AMBER: Color = Color(0.729, 0.459, 0.09)
const COLOR_RED: Color = Color(0.886, 0.294, 0.29)
const COLOR_TERTIARY: Color = Color(0.35, 0.37, 0.42, 1.0)
const ConnectionCanvasScript: GDScript = preload("res://ui/overlays/government_connection_canvas.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.12, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	# Header
	var header: PanelContainer = PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.1, 0.12, 0.18, 1.0)
	header_style.set_content_margin_all(12)
	header.add_theme_stylebox_override("panel", header_style)
	vbox.add_child(header)
	var header_h: HBoxContainer = HBoxContainer.new()
	header_h.add_theme_constant_override("separation", 16)
	header.add_child(header_h)
	_header_title = Label.new()
	_header_title.add_theme_font_size_override("font_size", 22)
	_header_title.add_theme_color_override("font_color", Color(0.95, 0.95, 1, 1))
	header_h.add_child(_header_title)
	header_h.add_child(Control.new())
	var stability_label: Label = Label.new()
	stability_label.text = "Stability"
	stability_label.add_theme_font_size_override("font_size", 14)
	header_h.add_child(stability_label)
	_stability_bar = ProgressBar.new()
	_stability_bar.custom_minimum_size.x = 200.0
	_stability_bar.max_value = 100.0
	_stability_bar.show_percentage = false
	header_h.add_child(_stability_bar)
	header_h.add_child(Control.new())
	var btn_demo: Button = Button.new()
	btn_demo.text = "Democracy"
	btn_demo.pressed.connect(_on_type_pressed.bind(GovernmentManager.GovernmentType.DEMOCRACY))
	header_h.add_child(btn_demo)
	var btn_olig: Button = Button.new()
	btn_olig.text = "Oligarchy"
	btn_olig.pressed.connect(_on_type_pressed.bind(GovernmentManager.GovernmentType.OLIGARCHY))
	header_h.add_child(btn_olig)
	var btn_auto: Button = Button.new()
	btn_auto.text = "Autocracy"
	btn_auto.pressed.connect(_on_type_pressed.bind(GovernmentManager.GovernmentType.AUTHORITARIANISM))
	header_h.add_child(btn_auto)
	var btn_theo: Button = Button.new()
	btn_theo.text = "Theocracy"
	btn_theo.pressed.connect(_on_type_pressed.bind(GovernmentManager.GovernmentType.THEOCRACY))
	header_h.add_child(btn_theo)
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	header_h.add_child(close_btn)
	# Row 1: Key holder cards
	_keys_row = HBoxContainer.new()
	_keys_row.custom_minimum_size.y = KEYS_ROW_HEIGHT
	_keys_row.add_theme_constant_override("separation", 2)
	vbox.add_child(_keys_row)
	# Routing zone: space for connection lines to fan horizontally (above category panels)
	_routing_zone = Control.new()
	_routing_zone.custom_minimum_size.y = ROUTING_ZONE_HEIGHT
	_routing_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_routing_zone)
	# Canvas area (category panels, lines, detail right)
	_canvas_area = Control.new()
	_canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_canvas_area)
	# Connection canvas (full area, behind UI; must IGNORE mouse)
	_connection_canvas = Control.new()
	_connection_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_connection_canvas.offset_left = 0.0
	_connection_canvas.offset_top = 0.0
	_connection_canvas.offset_right = 0.0
	_connection_canvas.offset_bottom = 0.0
	_connection_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connection_canvas.set_script(ConnectionCanvasScript)
	_connection_canvas.set_meta("routing_zone", _routing_zone)
	_canvas_area.add_child(_connection_canvas)
	# Click catcher was blocking sliders — IGNORE so policy rows receive clicks
	var click_catcher: Control = Control.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.anchor_left = 0.0
	click_catcher.anchor_right = 1.0
	click_catcher.offset_left = 0.0
	click_catcher.offset_right = -DETAIL_PANEL_WIDTH
	click_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_catcher.gui_input.connect(_on_canvas_area_gui_input)
	_canvas_area.add_child(click_catcher)
	# Categories on top so sliders/key targets receive input
	_categories_container = HBoxContainer.new()
	_categories_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_categories_container.anchor_right = 1.0
	_categories_container.offset_right = -DETAIL_PANEL_WIDTH
	_categories_container.add_theme_constant_override("separation", 0)
	_categories_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_area.add_child(_categories_container)
	# Detail panel (right)
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	_detail_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_detail_panel.anchor_left = 1.0
	_detail_panel.anchor_top = 0.0
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_bottom = 1.0
	_detail_panel.offset_left = -DETAIL_PANEL_WIDTH
	_detail_panel.offset_top = 0.0
	_detail_panel.offset_right = 0.0
	_detail_panel.offset_bottom = 0.0
	var dp_style := StyleBoxFlat.new()
	dp_style.bg_color = Color(0.08, 0.09, 0.14, 1.0)
	dp_style.set_content_margin_all(16)
	_detail_panel.add_theme_stylebox_override("panel", dp_style)
	_canvas_area.add_child(_detail_panel)
	var dp_vbox: VBoxContainer = VBoxContainer.new()
	dp_vbox.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(dp_vbox)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color(0.95, 0.95, 1, 1))
	dp_vbox.add_child(_detail_title)
	_detail_subtitle = Label.new()
	_detail_subtitle.add_theme_font_size_override("font_size", 11)
	_detail_subtitle.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 1))
	dp_vbox.add_child(_detail_subtitle)
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 12)
	_detail_desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8, 1))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = DETAIL_PANEL_WIDTH - 48
	dp_vbox.add_child(_detail_desc)
	_detail_demand = PanelContainer.new()
	var demand_style := StyleBoxFlat.new()
	demand_style.bg_color = Color(0.55, 0.45, 0.15, 0.4)
	demand_style.set_content_margin_all(8)
	_detail_demand.add_theme_stylebox_override("panel", demand_style)
	_detail_demand.visible = false
	dp_vbox.add_child(_detail_demand)
	_detail_demand_label = Label.new()
	_detail_demand_label.add_theme_font_size_override("font_size", 11)
	_detail_demand.add_child(_detail_demand_label)
	var conn_label: Label = Label.new()
	conn_label.text = "Connections"
	conn_label.add_theme_font_size_override("font_size", 12)
	dp_vbox.add_child(conn_label)
	_detail_connections = VBoxContainer.new()
	_detail_connections.add_theme_constant_override("separation", 6)
	dp_vbox.add_child(_detail_connections)
	_detail_actions = VBoxContainer.new()
	_detail_actions.add_theme_constant_override("separation", 6)
	dp_vbox.add_child(_detail_actions)
	if EventBus != null:
		EventBus.key_holder_loyalty_changed.connect(_on_loyalty_or_stability_changed)
		EventBus.power_stability_changed.connect(_on_loyalty_or_stability_changed)
		EventBus.demand_fulfilled.connect(_on_loyalty_or_stability_changed)
	_refresh_panels()
	if _connection_canvas != null:
		_connection_canvas.queue_redraw()


func _on_type_pressed(type: int) -> void:
	if GovernmentManager == null:
		return
	GovernmentManager.rebuild_for_government_type(type as GovernmentManager.GovernmentType)
	selected_item = {}
	_refresh_panels()
	_connection_canvas_dirty = true


func _on_loyalty_or_stability_changed(_arg1: Variant = null, _arg2: Variant = null) -> void:
	_refresh_panels()
	_connection_canvas_dirty = true


func _refresh_panels() -> void:
	_update_header()
	_build_keys_row()
	_build_policy_panel()
	_update_detail_panel()
	_connection_canvas_dirty = true


func _update_header() -> void:
	if GovernmentManager == null:
		return
	var gov_name: String = "Democracy"
	match GovernmentManager.current_government_type:
		GovernmentManager.GovernmentType.OLIGARCHY:
			gov_name = "Oligarchy"
		GovernmentManager.GovernmentType.AUTHORITARIANISM:
			gov_name = "Authoritarianism"
		GovernmentManager.GovernmentType.THEOCRACY:
			gov_name = "Theocracy"
	if _header_title != null:
		_header_title.text = gov_name
	if _stability_bar != null and GovernmentManager != null:
		_stability_bar.max_value = 100.0
		_stability_bar.value = GovernmentManager.get_power_stability()


func _loyalty_color(loyalty: float) -> Color:
	if loyalty > 65.0:
		return COLOR_GREEN
	if loyalty >= 40.0:
		return COLOR_AMBER
	return COLOR_RED


func _build_keys_row() -> void:
	_holder_cards.clear()
	_holder_dots.clear()
	if _keys_row == null or GovernmentManager == null:
		return
	for c in _keys_row.get_children():
		c.queue_free()
	for kh in GovernmentManager.active_key_holders:
		var card: Control = _make_key_holder_card(kh)
		_keys_row.add_child(card)
		_holder_cards[kh.id] = card


func _make_key_holder_card(kh: KeyHolder) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_meta("holder_id", kh.id)
	panel.custom_minimum_size.x = KEY_CARD_MIN_WIDTH
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(_on_card_gui_input.bind(kh.id))
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var name_label: Label = Label.new()
	name_label.text = kh.display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	vbox.add_child(name_label)
	var loyalty_bar: ProgressBar = ProgressBar.new()
	loyalty_bar.min_value = 0.0
	loyalty_bar.max_value = 100.0
	loyalty_bar.value = kh.loyalty
	loyalty_bar.custom_minimum_size.y = 4
	loyalty_bar.show_percentage = false
	var bar_col: Color = _loyalty_color(kh.loyalty)
	loyalty_bar.modulate = bar_col
	vbox.add_child(loyalty_bar)
	var pct_label: Label = Label.new()
	pct_label.text = "%d%%" % [int(kh.loyalty)]
	pct_label.add_theme_font_size_override("font_size", 11)
	pct_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 1))
	vbox.add_child(pct_label)
	var dot_wrapper: CenterContainer = CenterContainer.new()
	dot_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dot: PanelContainer = PanelContainer.new()
	dot.custom_minimum_size = Vector2(8, 8)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = _loyalty_color(kh.loyalty)
	dot_style.set_corner_radius_all(4)
	dot_style.set_content_margin_all(0)
	dot.add_theme_stylebox_override("panel", dot_style)
	dot_wrapper.add_child(dot)
	vbox.add_child(dot_wrapper)
	panel.set_meta("anchor_dot", dot)
	_holder_dots[kh.id] = dot
	return panel


func _on_card_gui_input(event: InputEvent, holder_id: StringName) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if selected_item.get("type") == "holder" and selected_item.get("id") == holder_id:
				selected_item = {}
				_detail_panel.visible = false
			else:
				selected_item = {"type": "holder", "id": holder_id}
				_update_detail_panel()
				_detail_panel.visible = true
			_connection_canvas_dirty = true
			_connection_canvas.queue_redraw()
			_update_selection_visuals()


func _build_policy_panel() -> void:
	_policy_sliders.clear()
	_policy_dots.clear()
	_policy_wrappers.clear()
	if _categories_container == null or GovernmentManager == null:
		return
	for c in _categories_container.get_children():
		c.queue_free()
	for cat in GovernmentManager.categories:
		var column: Control = _make_category_column(cat)
		_categories_container.add_child(column)
	_connection_canvas_dirty = true


func _make_category_column(cat) -> Control:
	# AUDIT: NEEDS REVIEW — category panel width is equal share of container; total may exceed canvas at low resolution.
	var col_vbox: VBoxContainer = VBoxContainer.new()
	col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_vbox.add_theme_constant_override("separation", 8)
	var first_idx: int = _categories_container.get_child_count()
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.set_border_width_all(0)
	if first_idx > 0:
		border_style.set_border_width(SIDE_LEFT, int(CATEGORY_BORDER_WIDTH))
		border_style.border_color = COLOR_TERTIARY
	var column_wrapper: PanelContainer = PanelContainer.new()
	column_wrapper.add_theme_stylebox_override("panel", border_style)
	column_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column_wrapper.add_child(col_vbox)
	# Header
	var header: Label = Label.new()
	header.text = cat.display_name
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", COLOR_TERTIARY)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_vbox.add_child(header)
	# Separator
	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = COLOR_TERTIARY
	col_vbox.add_child(sep)
	# Policy list: VBox or ScrollContainer if >5
	var policy_list: VBoxContainer = VBoxContainer.new()
	policy_list.add_theme_constant_override("separation", 10)
	if cat.policies.size() > CATEGORY_MAX_POLICIES_BEFORE_SCROLL:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(policy_list)
		col_vbox.add_child(scroll)
	else:
		col_vbox.add_child(policy_list)
	for lever in cat.policies:
		var wrapper: PanelContainer = _make_policy_row(lever, policy_list)
		if wrapper != null:
			_policy_wrappers[lever.id] = wrapper
	if first_idx > 0:
		var gutter: MarginContainer = MarginContainer.new()
		gutter.add_theme_constant_override("margin_left", CATEGORY_COLUMN_GUTTER)
		gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gutter.add_child(column_wrapper)
		return gutter
	return column_wrapper


func _make_policy_row(lever: PolicyLever, parent: VBoxContainer) -> PanelContainer:
	var wrapper: PanelContainer = PanelContainer.new()
	wrapper.set_meta("policy_id", lever.id)
	var wrap_style := StyleBoxFlat.new()
	wrap_style.bg_color = Color(0.06, 0.07, 0.1, 0.6)
	wrap_style.set_corner_radius_all(2)
	wrap_style.set_content_margin_all(6)
	wrapper.add_theme_stylebox_override("panel", wrap_style)
	wrapper.gui_input.connect(_on_policy_row_gui_input.bind(lever.id))
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var lab: Label = Label.new()
	lab.text = lever.display_name
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 1))
	row.add_child(lab)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = lever.value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_policy_slider_changed.bind(lever.id))
	if lever.id == &"tax_rate":
		# Neutral tick must NOT be a second PanelContainer child — MarginContainer stacks both in the
		# same content rect and can expand the ColorRect to cover the whole row.
		var slider_slot: Control = Control.new()
		slider_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slider_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider_slot.custom_minimum_size.y = 22
		var neutral_mark: ColorRect = ColorRect.new()
		neutral_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		neutral_mark.color = Color(0.55, 0.58, 0.62, 0.95)
		neutral_mark.size = Vector2(1, 4)
		slider.set_anchors_preset(Control.PRESET_FULL_RECT)
		slider.offset_left = 0
		slider.offset_top = 0
		slider.offset_right = 0
		slider.offset_bottom = 0
		slider_slot.add_child(slider)
		slider_slot.add_child(neutral_mark)
		hbox.add_child(slider_slot)
		_position_tax_neutral_indicator(slider_slot, slider, neutral_mark)
		slider_slot.resized.connect(func(): _position_tax_neutral_indicator(slider_slot, slider, neutral_mark))
	else:
		hbox.add_child(slider)
	var pct: Label = Label.new()
	pct.custom_minimum_size.x = 26.0
	pct.text = "%d%%" % [int(lever.value * 100)]
	pct.add_theme_font_size_override("font_size", 10)
	pct.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1))
	slider.value_changed.connect(_on_policy_pct_update.bind(pct))
	hbox.add_child(pct)
	var dot: PanelContainer = PanelContainer.new()
	dot.custom_minimum_size = Vector2(6, 6)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0.45, 0.48, 0.55, 1)
	dot_style.set_corner_radius_all(3)
	dot_style.set_content_margin_all(0)
	dot.add_theme_stylebox_override("panel", dot_style)
	hbox.add_child(dot)
	row.add_child(hbox)
	wrapper.add_child(row)
	parent.add_child(wrapper)
	_policy_sliders[lever.id] = slider
	_policy_dots[lever.id] = dot
	_on_policy_pct_update(lever.value, pct)
	return wrapper


func _position_tax_neutral_indicator(slider_slot: Control, slider: HSlider, neutral_mark: ColorRect) -> void:
	if not is_instance_valid(slider_slot) or not is_instance_valid(slider) or not is_instance_valid(neutral_mark):
		return
	var sr: Rect2 = slider.get_global_rect()
	if sr.size.x <= 1.0:
		return
	var xform: Transform2D = slider_slot.get_global_transform_with_canvas().affine_inverse()
	var x25_global: float = sr.position.x + sr.size.x * 0.25
	var cy_global: float = sr.position.y + sr.size.y * 0.5
	var top_left: Vector2 = xform * Vector2(x25_global - 0.5, cy_global - 2.0)
	neutral_mark.position = top_left
	neutral_mark.size = Vector2(1, 4)


func _on_policy_row_gui_input(event: InputEvent, policy_id: StringName) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if selected_item.get("type") == "policy" and selected_item.get("id") == policy_id:
				selected_item = {}
				_detail_panel.visible = false
			else:
				selected_item = {"type": "policy", "id": policy_id}
				_update_detail_panel()
				_detail_panel.visible = true
			_connection_canvas_dirty = true
			_connection_canvas.queue_redraw()
			_update_selection_visuals()


func _on_policy_slider_changed(value: float, policy_id: StringName) -> void:
	if GovernmentManager == null:
		return
	for p in GovernmentManager.policy_levers:
		if p.id == policy_id:
			p.value = value
			break
	_connection_canvas_dirty = true
	if _connection_canvas != null:
		_connection_canvas.queue_redraw()


func _on_policy_pct_update(value: float, pct_label: Label) -> void:
	if pct_label != null:
		pct_label.text = "%d%%" % [int(value * 100)]


func _update_detail_panel() -> void:
	if _detail_title == null:
		return
	if selected_item.is_empty():
		_detail_panel.visible = false
		return
	_detail_panel.visible = true
	var st: String = selected_item.get("type", "")
	var id_val: Variant = selected_item.get("id", &"")
	if st == "holder":
		var kh: KeyHolder = _get_holder(id_val)
		if kh != null:
			_detail_title.text = kh.display_name
			_detail_subtitle.text = kh.faction_type
			_detail_desc.text = kh.description if kh.description else "No description."
			_detail_demand.visible = true
			_detail_demand_label.text = "Demand: %s %d" % [kh.demand_resource, kh.demand_amount]
			_populate_detail_connections_holder(id_val)
			_populate_detail_actions_holder(id_val)
	elif st == "policy":
		var lever: PolicyLever = _get_policy(id_val)
		if lever != null:
			_detail_title.text = lever.display_name
			_detail_subtitle.text = "Policy lever"
			_detail_desc.text = lever.description if lever.description else "No description."
			_detail_demand.visible = false
			_populate_detail_connections_policy(id_val)
			_populate_detail_actions_policy(id_val)


func _get_holder(holder_id: StringName) -> KeyHolder:
	if GovernmentManager == null:
		return null
	for kh in GovernmentManager.active_key_holders:
		if kh.id == holder_id:
			return kh
	return null


func _get_policy(policy_id: StringName) -> PolicyLever:
	if GovernmentManager == null:
		return null
	for p in GovernmentManager.policy_levers:
		if p.id == policy_id:
			return p
	return null


func _populate_detail_connections_holder(holder_id: StringName) -> void:
	for c in _detail_connections.get_children():
		c.queue_free()
	if GovernmentManager == null:
		return
	for link in GovernmentManager.get_active_connections():
		if link.get("holder_id", &"") != holder_id:
			continue
		var pid: StringName = link.get("policy_id", &"")
		var policy_name: String = _get_policy_display_name(pid)
		var dir: int = link.get("direction", 1)
		var line: String = policy_name + (" helps (+)" if dir >= 1 else " hurts (-)")
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = COLOR_GREEN if dir >= 1 else COLOR_RED
		row.add_child(dot)
		var lab: Label = Label.new()
		lab.text = line
		lab.add_theme_font_size_override("font_size", 11)
		row.add_child(lab)
		_detail_connections.add_child(row)


func _populate_detail_connections_policy(policy_id: StringName) -> void:
	for c in _detail_connections.get_children():
		c.queue_free()
	if GovernmentManager == null:
		return
	for link in GovernmentManager.get_active_connections():
		if link.get("policy_id", &"") != policy_id:
			continue
		var hid: StringName = link.get("holder_id", &"")
		var holder_name: String = _get_holder_display_name(hid)
		var dir: int = link.get("direction", 1)
		var line: String = holder_name + (" helps (+)" if dir >= 1 else " hurts (-)")
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = COLOR_GREEN if dir >= 1 else COLOR_RED
		row.add_child(dot)
		var lab: Label = Label.new()
		lab.text = line
		lab.add_theme_font_size_override("font_size", 11)
		row.add_child(lab)
		_detail_connections.add_child(row)


func _get_policy_display_name(pid: StringName) -> String:
	var p: PolicyLever = _get_policy(pid)
	return p.display_name if p != null else String(pid)


func _get_holder_display_name(hid: StringName) -> String:
	var kh: KeyHolder = _get_holder(hid)
	return kh.display_name if kh != null else String(hid)


func _populate_detail_actions_holder(holder_id: StringName) -> void:
	for c in _detail_actions.get_children():
		c.queue_free()
	var btn_satisfy: Button = Button.new()
	btn_satisfy.text = "Satisfy demand"
	btn_satisfy.pressed.connect(_on_satisfy_demand_pressed.bind(holder_id))
	_detail_actions.add_child(btn_satisfy)
	var btn_history: Button = Button.new()
	btn_history.text = "View loyalty history"
	btn_history.pressed.connect(_on_view_loyalty_history_pressed.bind(holder_id))
	_detail_actions.add_child(btn_history)


func _on_satisfy_demand_pressed(holder_id: StringName) -> void:
	satisfy_demand_requested.emit(holder_id)
	# TODO: wire to GovernmentManager.fulfill_demand when demand logic is in scope


func _on_view_loyalty_history_pressed(holder_id: StringName) -> void:
	view_loyalty_history_requested.emit(holder_id)


func _populate_detail_actions_policy(policy_id: StringName) -> void:
	for c in _detail_actions.get_children():
		c.queue_free()
	var btn_lock: Button = Button.new()
	btn_lock.text = "Lock this policy"
	btn_lock.pressed.connect(_on_lock_policy_pressed.bind(policy_id))
	_detail_actions.add_child(btn_lock)


func _on_lock_policy_pressed(policy_id: StringName) -> void:
	lock_policy_requested.emit(policy_id)


func _on_canvas_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			selected_item = {}
			_detail_panel.visible = false
			_connection_canvas_dirty = true
			_connection_canvas.queue_redraw()
			_update_selection_visuals()


func _update_selection_visuals() -> void:
	for hid in _holder_cards:
		var card: Control = _holder_cards[hid]
		if is_instance_valid(card) and card is PanelContainer:
			var style_ref = card.get_theme_stylebox("panel", "PanelContainer")
			var style: StyleBoxFlat = style_ref.duplicate() as StyleBoxFlat
			if style != null:
				var border: int = 2 if selected_item.get("type") == "holder" and selected_item.get("id") == hid else 0
				style.set_border_width_all(border)
				style.border_color = Color(0.216, 0.553, 0.867)
				card.add_theme_stylebox_override("panel", style)
	for rid in _policy_wrappers:
		var wrapper: Control = _policy_wrappers[rid]
		if is_instance_valid(wrapper) and wrapper is PanelContainer:
			var s: StyleBoxFlat = (wrapper as PanelContainer).get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
			if s != null:
				var border: int = 2 if selected_item.get("type") == "policy" and selected_item.get("id") == rid else 0
				s.set_border_width_all(border)
				s.border_color = Color(0.216, 0.553, 0.867)
				(wrapper as PanelContainer).add_theme_stylebox_override("panel", s)


func _process(_delta: float) -> void:
	# AUDIT: NEEDS REVIEW — coordinate retrieval depends on layout timing; zero-size guard skips until valid.
	policy_dot_centers.clear()
	holder_dot_centers.clear()
	for pid in _policy_dots:
		var d: Control = _policy_dots[pid]
		if is_instance_valid(d):
			var rect: Rect2 = d.get_global_rect()
			if rect.size != Vector2.ZERO:
				policy_dot_centers[pid] = rect.get_center()
	for hid in _holder_dots:
		var d: Control = _holder_dots[hid]
		if is_instance_valid(d):
			var rect: Rect2 = d.get_global_rect()
			if rect.size != Vector2.ZERO:
				holder_dot_centers[hid] = rect.get_center()
	if _connection_canvas_dirty and _connection_canvas != null:
		_connection_canvas_dirty = false
		_connection_canvas.queue_redraw()


func _on_close_pressed() -> void:
	closed.emit()
