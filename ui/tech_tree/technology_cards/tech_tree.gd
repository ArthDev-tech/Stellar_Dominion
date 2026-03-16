@tool
extends Control

signal closed()

@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0

@onready var close_button: Button = %CloseButton
@onready var research_button: Button = %ResearchButton
@onready var tree_canvas: Control = $ContentHBox/TreeCanvas
@onready var content_boundary: ReferenceRect = $ContentBoundary
@onready var research_status_label: Label = %ResearchStatus
@onready var research_progress_bar: ProgressBar = %ResearchProgress
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_name: Label = %NameLabel
@onready var detail_branch_tier: Label = %BranchTierLabel
@onready var detail_cost: Label = %CostLabel
@onready var detail_desc: Label = %DescLabel
@onready var detail_prereqs: Label = %PrereqsLabel
@onready var detail_research_button: Button = $DetailPanel/DetailVBox/ResearchButton
@onready var detail_queue_button: Button = $DetailPanel/DetailVBox/QueueButton

var _empire: Empire = null
var _available_tech_ids: Dictionary = {}
var _selected_tech_def: Dictionary = {}
var _selected_tech_id: String = ""
var _is_panning: bool = false
var _cards_connected: Dictionary = {}
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_pressed)
	research_button.pressed.connect(_on_research_pressed)
	research_button.disabled = true
	if not Engine.is_editor_hint():
		detail_panel.visible = false
	detail_research_button.pressed.connect(_on_research_pressed)
	detail_queue_button.pressed.connect(_on_queue_pressed)
	if Engine.is_editor_hint():
		return
	_populate_tech_cards()
	if _empire == null and EmpireManager != null:
		setup(EmpireManager.get_player_empire())
	else:
		_update_research_status()
	print("[TechTree] Tech tree initialized")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			if event.pressed:
				_pan_start_mouse = event.position
				_pan_start_pos = tree_canvas.position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_toward_point(event.position, 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_toward_point(event.position, -1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_panning:
		_do_pan(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _do_pan(mouse_pos: Vector2) -> void:
	var new_pos: Vector2 = _pan_start_pos + (mouse_pos - _pan_start_mouse)
	tree_canvas.position = new_pos
	_clamp_canvas_position()

func _zoom_toward_point(mouse_pos: Vector2, direction: float) -> void:
	var s: float = tree_canvas.scale.x
	var local_pt: Vector2 = (mouse_pos - tree_canvas.position) / s
	var new_scale: float = clampf(s + direction * zoom_step, zoom_min, zoom_max)
	tree_canvas.scale = Vector2(new_scale, new_scale)
	tree_canvas.position = mouse_pos - local_pt * new_scale
	_clamp_canvas_position()

func _clamp_canvas_position() -> void:
	var content_size: Vector2 = content_boundary.size
	var scaled: Vector2 = content_size * tree_canvas.scale
	# When content larger than view: clamp so we don't show empty space (position in [size - scaled, 0]).
	# When content smaller than view: allow pan so canvas can sit anywhere in view (position in [0, size - scaled]).
	var min_x: float = size.x - scaled.x
	var max_x: float = 0.0
	if min_x > max_x:
		min_x = 0.0
		max_x = size.x - scaled.x
	tree_canvas.position.x = clampf(tree_canvas.position.x, min_x, max_x)
	var min_y: float = size.y - scaled.y
	var max_y: float = 0.0
	if min_y > max_y:
		min_y = 0.0
		max_y = size.y - scaled.y
	tree_canvas.position.y = clampf(tree_canvas.position.y, min_y, max_y)

func _get_branch_colors() -> Dictionary:
	return {
		"physical": Color(0.0, 0.78, 1.0),
		"social": Color(1.0, 0.77, 0.3),
		"xenological": Color(0.71, 0.3, 1.0),
	}

func setup(empire: Empire) -> void:
	_empire = empire
	_available_tech_ids.clear()
	if _empire != null and ResearchManager != null:
		for t in ResearchManager.get_available_techs(_empire):
			var tid: String = t.get("id", "")
			if not tid.is_empty():
				_available_tech_ids[tid] = true
	_populate_tech_cards()
	_update_research_status()

func _update_research_status() -> void:
	if research_status_label == null:
		return
	if _empire == null or _empire.current_research_tech_id.is_empty():
		research_status_label.text = "No active research — select a technology to begin"
		if research_progress_bar != null:
			research_progress_bar.visible = false
		return
	var tid: String = _empire.current_research_tech_id
	var tech_def: Dictionary = ResearchManager.get_tech_def(tid) if ResearchManager else {}
	var name_key: String = tech_def.get("name_key", tid)
	var branch_key: String = ResearchManager.get_tech_branch_key(tech_def) if ResearchManager else ""
	var branch_initial: String = "P" if branch_key == "physical" else "S" if branch_key == "social" else "X"
	var branch_name: String = ResearchManager.BRANCH_NAMES.get(branch_key, branch_key) if ResearchManager else branch_key
	var tier: int = int(tech_def.get("tier", 1))
	var cost: float = float(tech_def.get("cost", 0))
	var current_rp: float = _empire.research_progress
	research_status_label.text = "[ %s ]  %s  ·  %s T%d  ·  %.0f / %.0f RP" % [branch_initial, name_key, branch_name, tier, current_rp, cost]
	if research_progress_bar != null:
		research_progress_bar.visible = true
		research_progress_bar.value = (current_rp / cost) if cost > 0.0 else 0.0

func _node_state(tech_id: String) -> String:
	if _empire == null:
		return "locked"
	if tech_id in _empire.completed_tech_ids:
		return "researched"
	if _empire.current_research_tech_id == tech_id:
		return "in_progress"
	if _available_tech_ids.get(tech_id, false):
		return "available"
	return "locked"

func _on_node_pressed(tech_def: Dictionary) -> void:
	_selected_tech_def = tech_def
	_selected_tech_id = tech_def.get("id", "")
	var branch_key: String = ResearchManager.get_tech_branch_key(tech_def) if ResearchManager else ""
	detail_name.text = tech_def.get("name_key", "?")
	detail_name.add_theme_color_override("font_color", _get_branch_colors().get(branch_key, Color.WHITE))
	detail_branch_tier.text = "%s — Tier %d" % [ResearchManager.BRANCH_NAMES.get(branch_key, branch_key) if ResearchManager else branch_key, int(tech_def.get("tier", 1))]
	detail_cost.text = "%d Research" % int(tech_def.get("cost", 0))
	var desc: String = tech_def.get("description", "")
	detail_desc.text = desc if desc != "" else "No description."
	detail_desc.visible = desc != ""
	var prereqs: Array = tech_def.get("prerequisites", [])
	if prereqs.is_empty():
		detail_prereqs.text = "None"
	else:
		var names: PackedStringArray = []
		for pid in prereqs:
			var d: Dictionary = ResearchManager.get_tech_def(pid) if ResearchManager else {}
			names.append(d.get("name_key", pid))
		detail_prereqs.text = ", ".join(names)
	var tid: String = tech_def.get("id", "")
	var available: bool = _available_tech_ids.get(tid, false)
	var no_current: bool = _empire != null and _empire.current_research_tech_id.is_empty()
	var state: String = _node_state(tid)
	research_button.disabled = !(available and no_current)
	detail_research_button.visible = available and no_current
	detail_queue_button.visible = (state == "locked" or state == "available") and _empire != null
	if state == "locked":
		detail_queue_button.text = "Queue this tech and prerequisites"
	else:
		detail_queue_button.text = "Queue this tech"
	detail_panel.visible = true

func _populate_tech_cards() -> void:
	var path := ProjectPaths.DATA_TECHS
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var techs: Array = json.data if json.data is Array else []
	var tech_by_id: Dictionary = {}
	for t in techs:
		var tid: String = t.get("id", "")
		if not tid.is_empty():
			tech_by_id[tid] = t
	for child in tree_canvas.get_children():
		if child.name == "Background" or child.name == "LinesLayer" or child.name.begins_with("BranchLabel"):
			continue
		if not child.name.begins_with("tech_"):
			continue
		var tech_def: Dictionary = tech_by_id.get(child.name, {})
		if tech_def.is_empty():
			tech_def = ResearchManager.get_tech_def(child.name) if ResearchManager else {}
		if tech_def.is_empty():
			continue
		var cat: int = int(tech_def.get("category", 0))
		var branch_key: String = ["physical", "social", "xenological"][clampi(cat, 0, 2)]
		if ResearchManager != null:
			branch_key = ResearchManager.get_tech_branch_key(tech_def)
		var state: String = _node_state(child.name) if _empire != null else "available"
		var card_state: String = "completed" if state == "researched" else state
		if child.has_method("apply_tech_def"):
			child.apply_tech_def(tech_def, branch_key, card_state)
		var cid: int = child.get_instance_id()
		if _cards_connected.get(cid, false):
			continue
		_cards_connected[cid] = true
		if child.has_signal("pressed"):
			child.pressed.connect(_on_node_pressed)
		else:
			var btn: Button = child.get_node_or_null("CardButton")
			if btn != null:
				btn.pressed.connect(_on_node_pressed.bind(tech_def))
		_apply_queue_order_to_card(child)

func _apply_queue_order_to_card(card: Control) -> void:
	const QUEUE_HIGHLIGHT := Color(1.0, 0.95, 0.7)
	var existing: Node = card.get_node_or_null("QueueOrderLabel")
	if existing != null:
		existing.queue_free()
	if _empire == null:
		card.modulate = Color.WHITE
		return
	var tid: String = card.name
	var idx: int = _empire.research_queue.find(tid)
	if idx < 0:
		card.modulate = Color.WHITE
		return
	card.modulate = QUEUE_HIGHLIGHT
	var order_label: Label = Label.new()
	order_label.name = "QueueOrderLabel"
	order_label.text = str(idx + 1)
	order_label.z_index = 10
	order_label.add_theme_font_size_override("font_size", 14)
	order_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	order_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	order_label.add_theme_constant_override("outline_size", 2)
	card.add_child(order_label)
	order_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	order_label.offset_left = -22
	order_label.offset_top = 4
	order_label.offset_right = -4
	order_label.offset_bottom = 22

func _on_close_pressed() -> void:
	# Defer so we're not inside the button's callback when the overlay is freed
	call_deferred("_emit_closed")

func _emit_closed() -> void:
	closed.emit()
	hide()
	print("[TechTree] Tech tree closed")

func _on_research_pressed() -> void:
	if _empire == null or _selected_tech_def.is_empty():
		return
	if not _empire.current_research_tech_id.is_empty():
		return
	var tid: String = _selected_tech_def.get("id", "")
	if not _available_tech_ids.get(tid, false):
		return
	_empire.current_research_tech_id = tid
	_empire.research_progress = 0.0
	_populate_tech_cards()
	_update_research_status()
	research_button.disabled = true
	detail_research_button.visible = false
	detail_branch_tier.text = detail_branch_tier.text + " — In progress"
	if EventBus != null:
		EventBus.tech_research_confirmed.emit(tid)
	print("[TechTree] Research confirmed: %s" % tid)

func _on_queue_pressed() -> void:
	if _empire == null or _selected_tech_def.is_empty():
		return
	var tid: String = _selected_tech_def.get("id", "")
	if _empire.completed_tech_ids.has(tid):
		return
	if ResearchManager != null:
		ResearchManager.queue_tech_and_prerequisites(_empire, tid)
	_populate_tech_cards()
	detail_queue_button.visible = false
	detail_branch_tier.text = detail_branch_tier.text + " — Queued"

func select_tech(tech_id: String) -> void:
	_selected_tech_id = tech_id
	research_button.disabled = tech_id.is_empty()

func deselect_tech() -> void:
	_selected_tech_id = ""
	_selected_tech_def = {}
	research_button.disabled = true
	detail_panel.visible = false
