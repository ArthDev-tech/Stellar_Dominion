extends Node2D
## Game scene: galaxy map, system selection, camera pan/zoom, speed controls.

## Optional: assign a GameplayConfig resource to tune time, zoom, and layout in the inspector.
@export var gameplay_config: GameplayConfig = null
## Overlay scenes (assign in inspector to swap or test; empty = use built-in preload).
@export var overlay_colonies: PackedScene = null
@export var overlay_technology: PackedScene = null
@export var overlay_tech_tree: PackedScene = null
@export var overlay_leaders: PackedScene = null
@export var overlay_planet_view: PackedScene = null
@export var overlay_space_station: PackedScene = null
@export var overlay_ship_designer: PackedScene = null

@onready var galaxy_map: Node2D = $GalaxyMap
@onready var camera: Camera2D = $Camera2D
@onready var hyperlines: Node2D = $GalaxyMap/Hyperlines
@onready var systems_layer: Node2D = $GalaxyMap/SystemsLayer
@onready var ships_layer: Node2D = $GalaxyMap/ShipsLayer
var _route_preview_line: Line2D = null  ## Child of GalaxyMap/RoutePreviewLayer, created in _ready
@onready var top_bar: PanelContainer = $UICanvas/TopBar
@onready var pause_button: Button = $UICanvas/TopBar/MarginContainer/VBox/Row1/PauseButton
@onready var selected_panel: PanelContainer = $UICanvas/SelectedPanel
var selected_label: Label
var view_system_button: Button
var survey_button: Button
var manage_colony_button: Button
var manage_station_button: Button
@onready var resource_strip_line1: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row1/ResourceLine1
@onready var resource_strip_line2: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row2/ResourceLine2
@onready var top_bar_vbox: VBoxContainer = $UICanvas/TopBar/MarginContainer/VBox
@onready var date_label: Label = $UICanvas/TopBar/MarginContainer/VBox/Row1/DateLabel
@onready var research_label: Label = $UICanvas/ResearchPanel/MarginContainer/VBox/ResearchLabel
@onready var tech1_btn: Button = $UICanvas/ResearchPanel/MarginContainer/VBox/DrawHBox/Tech1Btn
@onready var tech2_btn: Button = $UICanvas/ResearchPanel/MarginContainer/VBox/DrawHBox/Tech2Btn
@onready var tech3_btn: Button = $UICanvas/ResearchPanel/MarginContainer/VBox/DrawHBox/Tech3Btn
@onready var overlay_layer: CanvasLayer = $OverlayLayer
@onready var planets_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/PlanetsButton
@onready var technology_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/TechnologyButton
@onready var tech_tree_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/TechTreeButton
@onready var leaders_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/LeadersButton
@onready var ship_designer_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/ShipDesignerButton
@onready var music_player_panel: PanelContainer = $UICanvas/MusicPlayerPanel
@onready var music_play_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicPlayButton
@onready var music_pause_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicPauseButton
@onready var music_next_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicNextButton
@onready var music_volume_slider: HSlider = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicVolumeSlider

var selected_panel_vbox: VBoxContainer
@onready var galaxy_selection_handler: Control = $SelectionOverlay/GalaxySelectionHandler
@onready var ui_canvas: CanvasLayer = $UICanvas
@onready var nav_strip: PanelContainer = $UICanvas/NavStrip
@onready var scale_buttons_container: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row1/ScaleButtonsContainer

var _zoom_level: float = 1.0
var _scale_buttons: Array[Button] = []
var _active_nav_button: Button = null
var _send_ships_container: VBoxContainer = null
var _station_buttons_container: VBoxContainer = null  ## When system has multiple stations, holds one button per station
var _galaxy_ship_filter: String = "all"  ## "all" | "science" | "construction" | "military"
var _galaxy_selected_indicator: String = ""  ## "science" | "construction" | "military" | "station" when an indicator is selected
var _dragging: bool = false
var _drag_start: Vector2
var _day_accumulator: float = 0.0
var _indicator_redraw_timer: float = 0.0
var _hover_tooltip: Control = null
var _hover_accumulator: float = 0.0
var _hover_last_system_id: int = -2
var _hover_last_indicator: String = ""
var _resource_hover_type: int = -1
var _resource_strip_controller: ResourceStripController = null
var _research_panel_controller: ResearchPanelController = null


func _get_cfg() -> GameplayConfig:
	return gameplay_config


func _seconds_per_day() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.get_seconds_per_day() if c != null else 2.0 / 30.0


func _zoom_speed() -> float:
	if camera != null and camera.get_script() != null and "zoom_step" in camera:
		return 1.0 + camera.zoom_step
	var c: GameplayConfig = _get_cfg()
	return c.zoom_speed if c != null else 1.1


func _min_zoom() -> float:
	if camera != null and camera.get_script() != null and "zoom_min" in camera:
		return camera.zoom_min
	var c: GameplayConfig = _get_cfg()
	return c.min_zoom if c != null else 0.3


func _max_zoom() -> float:
	if camera != null and camera.get_script() != null and "zoom_max" in camera:
		return camera.zoom_max
	var c: GameplayConfig = _get_cfg()
	return c.max_zoom if c != null else 2.0


func _click_max_distance() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.click_max_distance if c != null else 25.0


func _star_radius_for_indicators() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.star_radius_for_indicators if c != null else 8.0


func _indicator_y_offset() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.indicator_y_offset if c != null else 14.0


func _indicator_size() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.indicator_size if c != null else 3.0


func _indicator_dx() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.indicator_dx if c != null else 8.0


func _galaxy_click_drag_threshold() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.galaxy_click_drag_threshold if c != null else 5.0


func _hover_delay_seconds() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.hover_delay_seconds if c != null else 0.35


func _indicator_redraw_interval() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.indicator_redraw_interval if c != null else 1.0


func _overlay_dimmer_color() -> Color:
	var c: GameplayConfig = _get_cfg()
	return c.overlay_dimmer_color if c != null else Color(0, 0, 0, 0.55)


func _overlay_rect(rect_key: String) -> Vector4:
	var c: GameplayConfig = _get_cfg()
	if c == null:
		match rect_key:
			"colonies": return Vector4(-280, -220, 280, 220)
			"technology": return Vector4(-320, -240, 320, 240)
			"leaders": return Vector4(-260, -200, 260, 200)
			"planet_view": return Vector4(-675, -540, 675, 540)
			"station": return Vector4(-450, -350, 450, 350)
			"ship_designer": return Vector4(-470, -310, 470, 310)
			_: return Vector4(-300, -200, 300, 200)
	match rect_key:
		"colonies": return c.overlay_colonies_rect
		"technology": return c.overlay_technology_rect
		"leaders": return c.overlay_leaders_rect
		"planet_view": return c.overlay_planet_view_rect
		"station": return c.overlay_station_rect
		"ship_designer": return c.overlay_ship_designer_rect
		_: return c.overlay_colonies_rect


func _ui_theme() -> UIThemeOverrides:
	var c: GameplayConfig = _get_cfg()
	return c.ui_theme if c != null else null


func _instantiate_overlay(export_scene: PackedScene, fallback_path: String) -> Node:
	if export_scene != null:
		return export_scene.instantiate()
	return (load(fallback_path) as PackedScene).instantiate()


func _ready() -> void:
	# Resolve selected panel content (no wrapper — direct MarginContainer/VBoxContainer)
	var content_vbox: VBoxContainer = selected_panel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if content_vbox != null:
		selected_panel_vbox = content_vbox
		selected_label = content_vbox.get_node_or_null("SelectedLabel") as Label
		view_system_button = content_vbox.get_node_or_null("ViewSystemButton") as Button
		survey_button = content_vbox.get_node_or_null("SurveyButton") as Button
		manage_colony_button = content_vbox.get_node_or_null("ManageColonyButton") as Button
		manage_station_button = content_vbox.get_node_or_null("ManageStationButton") as Button
	if GalaxyManager.galaxy == null:
		var c: GameplayConfig = _get_cfg()
		var sys_count: int = c.galaxy_system_count if c != null else 50
		var seed_val: int = c.galaxy_seed if c != null else -1
		var num_ai: int = c.galaxy_num_ai_empires if c != null else 2
		GalaxyManager.generate_galaxy(sys_count, seed_val, num_ai)
		EmpireManager.create_empires_from_galaxy(GalaxyManager.galaxy)
	GalaxyManager.galaxy_generated.connect(_build_galaxy_map)
	_build_galaxy_map()
	_setup_route_preview_layer()
	_center_camera_on_galaxy()
	GameState.system_selected.connect(_on_system_selected)
	pause_button.toggled.connect(_on_pause_toggled)
	_build_scale_buttons()
	if EventBus != null:
		EventBus.pause_state_changed.connect(_on_pause_state_changed)
	GameState.game_speed_changed.connect(_update_speed_buttons)
	if view_system_button != null:
		view_system_button.pressed.connect(_on_view_system_pressed)
	if survey_button != null:
		survey_button.pressed.connect(_on_survey_pressed)
	if manage_colony_button != null:
		manage_colony_button.pressed.connect(_on_manage_colony_pressed)
	if manage_station_button != null:
		manage_station_button.pressed.connect(_on_manage_station_pressed)
	_resource_strip_controller = ResourceStripController.new()
	_resource_strip_controller.setup(resource_strip_line1, resource_strip_line2, top_bar_vbox, date_label, func(): return _ui_theme(), func(): return _get_cfg())
	_resource_strip_controller.resource_row_entered.connect(_on_resource_row_entered)
	_resource_strip_controller.resource_row_exited.connect(_on_resource_row_exited)
	_resource_strip_controller.build_resource_strip()
	_research_panel_controller = ResearchPanelController.new()
	_research_panel_controller.setup(research_label, tech1_btn, tech2_btn, tech3_btn)
	tech1_btn.pressed.connect(_on_tech_draw_1_pressed)
	tech2_btn.pressed.connect(_on_tech_draw_2_pressed)
	tech3_btn.pressed.connect(_on_tech_draw_3_pressed)
	planets_button.pressed.connect(_on_planets_pressed)
	technology_button.pressed.connect(_on_technology_pressed)
	tech_tree_button.pressed.connect(_on_tech_tree_pressed)
	leaders_button.pressed.connect(_on_leaders_pressed)
	if ship_designer_button != null:
		ship_designer_button.pressed.connect(_on_ship_designer_pressed)
	if music_play_button != null:
		music_play_button.pressed.connect(MusicPlayer.play)
	if music_pause_button != null:
		music_pause_button.pressed.connect(MusicPlayer.pause)
	if music_next_button != null:
		music_next_button.pressed.connect(MusicPlayer.next_track)
	if MusicPlayer != null:
		MusicPlayer.playback_state_changed.connect(_on_music_playback_state_changed)
		_on_music_playback_state_changed(MusicPlayer.is_playing())
	if music_volume_slider != null:
		music_volume_slider.value = MusicPlayer.get_volume_linear() if MusicPlayer != null else 0.15
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	_setup_hover_tooltip()
	_setup_send_ships_container()
	_update_selected_panel()
	_update_speed_buttons()
	_resource_strip_controller.update_resource_display()
	_research_panel_controller.update_research_panel()
	_apply_ui_canvas_styles()
	if SelectionManager != null:
		SelectionManager.clear_selection()


func _process(delta: float) -> void:
	_update_route_preview()
	if GameState.game_phase == GameState.GamePhase.PLAYING:
		_resource_strip_controller.update_resource_display()
		_update_hover_tooltip(delta)
		_indicator_redraw_timer += delta
		if _indicator_redraw_timer >= _indicator_redraw_interval():
			_indicator_redraw_timer = 0.0
			for c in systems_layer.get_children():
				c.queue_redraw()
			_refresh_galaxy_ship_nodes()
	if GameState.is_paused() or GameState.game_phase != GameState.GamePhase.PLAYING:
		return
	var mult: float = GameState.get_time_scale_multiplier()
	_day_accumulator += delta * mult / _seconds_per_day()
	# Advance by fractional days per frame so ship movement is smooth at low speed (e.g. 0.1x)
	var max_step: float = clampf(0.25 * mult, 0.02, 1.0)
	var step_days: float = minf(_day_accumulator, max_step)
	if step_days >= 0.0001:
		GameState.advance_day(step_days)
		_day_accumulator -= step_days
	if _day_accumulator < 0.0:
		_day_accumulator = 0.0
	_research_panel_controller.update_research_panel()


func _build_galaxy_map() -> void:
	_clear_galaxy_children()
	var galaxy = GalaxyManager.galaxy
	if galaxy == null:
		return
	for h in galaxy.hyperlanes:
		var from_sys := GalaxyManager.get_system(h.from_id)
		var to_sys := GalaxyManager.get_system(h.to_id)
		if from_sys != null and to_sys != null:
			var line := Line2D.new()
			line.add_point(from_sys.position)
			line.add_point(to_sys.position)
			var c: GameplayConfig = _get_cfg()
			line.width = c.hyperline_width if c != null else 1.5
			line.default_color = c.hyperline_color if c != null else Color(0.35, 0.4, 0.6, 0.8)
			hyperlines.add_child(line)
	for s in galaxy.systems:
		var node := Node2D.new()
		node.position = s.position
		node.set_script(preload("res://scenes/galaxy/star_system_node.gd"))
		node.set_meta("system_id", s.id)
		systems_layer.add_child(node)
	_refresh_galaxy_ship_nodes()


func _clear_galaxy_children() -> void:
	for c in hyperlines.get_children():
		c.queue_free()
	for c in systems_layer.get_children():
		c.queue_free()
	if ships_layer != null:
		for c in ships_layer.get_children():
			c.queue_free()


func _refresh_galaxy_ship_nodes() -> void:
	if ships_layer == null or EmpireManager == null or GalaxyManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var previously_selected_fleet_ids: Array = []
	if SelectionManager != null:
		for n in SelectionManager.selected_ships:
			if is_instance_valid(n):
				var fd: FleetData = n.get_meta("fleet_data", null) as FleetData
				if fd == null and "fleet_data" in n:
					fd = n.fleet_data
				if fd != null and fd.fleet_id != "":
					previously_selected_fleet_ids.append(fd.fleet_id)
	for c in ships_layer.get_children():
		c.queue_free()
	var script_fleet_icon: GDScript = preload("res://scenes/galaxy/fleet_galaxy_icon.gd") as GDScript
	var ships_by_system: Dictionary = {}  # (empire_id, system_id) -> Array[Ship]
	for ship in player_emp.ships:
		var s: Ship = ship as Ship
		if s == null or s.in_hyperlane:
			continue
		var key: String = "e%d_s%d" % [s.empire_id, s.system_id]
		if not ships_by_system.has(key):
			ships_by_system[key] = []
		ships_by_system[key].append(s)
	for key in ships_by_system:
		var ship_list: Array = ships_by_system[key]
		if ship_list.is_empty():
			continue
		var first: Ship = ship_list[0] as Ship
		if first == null:
			continue
		var sys: StarSystem = GalaxyManager.get_system(first.system_id)
		if sys == null:
			continue
		var fleet_data: FleetData = FleetData.new()
		fleet_data.fleet_id = "emp_%d_sys_%d" % [first.empire_id, first.system_id]
		fleet_data.fleet_name = "Fleet"
		fleet_data.owner_empire_id = str(first.empire_id)
		fleet_data.current_system_id = str(first.system_id)
		for ship in ship_list:
			var s: Ship = ship as Ship
			if s == null:
				continue
			var sd: ShipData = ShipData.new()
			sd.ship_name = s.name_key
			sd.ship_class = EconomyManager.get_ship_display_type(s.design_id) if EconomyManager != null else "construction"
			sd.combat_power = 0.0
			sd.hull_current = 100.0
			sd.hull_max = 100.0
			fleet_data.ships.append(sd)
		var node: Node2D = Node2D.new()
		node.position = sys.position
		node.set_script(script_fleet_icon)
		node.fleet_data = fleet_data
		node.empire_color = player_emp.color
		node.set_meta("fleet_data", fleet_data)
		node.add_to_group("galaxy_ships")
		ships_layer.add_child(node)
	if SelectionManager != null and previously_selected_fleet_ids.size() > 0:
		var to_select: Array = []
		for c in ships_layer.get_children():
			var fd: FleetData = c.get_meta("fleet_data", null) as FleetData
			if fd == null and "fleet_data" in c:
				fd = c.fleet_data
			if fd != null and fd.fleet_id in previously_selected_fleet_ids:
				to_select.append(c)
		if to_select.size() > 0:
			SelectionManager.set_selection(to_select)


func _setup_route_preview_layer() -> void:
	var c: GameplayConfig = _get_cfg()
	var layer: Node2D = Node2D.new()
	layer.name = "RoutePreviewLayer"
	layer.z_index = c.route_preview_z_index if c != null else 10
	galaxy_map.add_child(layer)
	_route_preview_line = Line2D.new()
	_route_preview_line.width = c.route_preview_width if c != null else 3.0
	_route_preview_line.default_color = c.route_preview_color if c != null else Color(1.0, 0.85, 0.2, 0.95)
	_route_preview_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_route_preview_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	layer.add_child(_route_preview_line)


func _update_route_preview() -> void:
	if _route_preview_line == null:
		return
	_route_preview_line.clear_points()
	var sid: int = GameState.selected_system_id
	if sid < 0 or GalaxyManager == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var rep_ship: Ship = null
	for s in player_emp.ships:
		var ship: Ship = s as Ship
		if ship == null or ship.system_id != sid or ship.in_hyperlane:
			continue
		if ship.target_system_id >= 0 or ship.path_queue.size() > 0:
			rep_ship = ship
			break
	if rep_ship == null:
		return
	var path_ids: Array[int] = [rep_ship.system_id]
	if rep_ship.target_system_id >= 0:
		path_ids.append(rep_ship.target_system_id)
	for i in rep_ship.path_queue.size():
		path_ids.append(rep_ship.path_queue[i])
	if path_ids.size() < 2:
		return
	for id in path_ids:
		var sys: StarSystem = GalaxyManager.get_system(id)
		if sys != null:
			_route_preview_line.add_point(sys.position)


func _center_camera_on_galaxy() -> void:
	var galaxy = GalaxyManager.galaxy
	if galaxy == null or galaxy.systems.is_empty():
		return
	var home_id: int = galaxy.player_home_system_id
	var sys: StarSystem = GalaxyManager.get_system(home_id) if home_id >= 0 else galaxy.systems[0]
	if sys != null:
		camera.position = sys.position


func _unhandled_input(event: InputEvent) -> void:
	var vp = get_viewport()
	if vp == null:
		return
	# LMB release: run selection handler first so ship/box selection takes priority. Only change system when no ship was selected.
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if galaxy_selection_handler != null and galaxy_selection_handler.has_method("process_input"):
				if galaxy_selection_handler.process_input(event, e.position):
					vp.set_input_as_handled()
					return
				# Handler did not consume (no ship/box selected): select system and optional indicator.
				_try_select_system_at(e.position)
				vp.set_input_as_handled()
				return
	# Delegate LMB press and drag motion to selection handler (box/click select)
	if galaxy_selection_handler != null and galaxy_selection_handler.has_method("process_input"):
		if event is InputEventMouseButton:
			var e: InputEventMouseButton = event
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				if galaxy_selection_handler.process_input(event):
					vp.set_input_as_handled()
					return
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if galaxy_selection_handler.process_input(event):
				vp.set_input_as_handled()
				return
	# Middle mouse and wheel must be in _input() so they are received before UI consumes them
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level * _zoom_speed())
			vp.set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level / _zoom_speed())
			vp.set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				_dragging = true
				_drag_start = e.position
			else:
				_dragging = false
			vp.set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			_try_select_system_at(e.position)
			vp.set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_RIGHT and not e.pressed:
			_handle_right_click_galaxy(e.position)
			vp.set_input_as_handled()
	if event is InputEventMouseMotion and _dragging:
		var e: InputEventMouseMotion = event
		var delta := (e.position - _drag_start) / _zoom_level
		camera.position -= delta
		_drag_start = e.position
		vp.set_input_as_handled()


func _try_select_system_at(screen_pos: Vector2) -> void:
	var best_id := _get_hover_system_id_at(screen_pos)
	if best_id < 0:
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var indicator: String = _get_ship_indicator_at(best_id, world_pos)
	if indicator == "science" or indicator == "construction" or indicator == "military" or indicator == "station":
		_galaxy_ship_filter = indicator
	_galaxy_selected_indicator = indicator if not indicator.is_empty() else ""
	GameState.set_selected_system(best_id)
	# Always refresh panel and indicator highlight (e.g. when clicking a different indicator on same system, GameState may not emit).
	_update_selected_panel()
	for c in systems_layer.get_children():
		if c.get_meta("system_id", -1) == GameState.selected_system_id:
			c.set_meta("highlighted_indicator", _galaxy_selected_indicator)
		else:
			c.set_meta("highlighted_indicator", "")
		c.queue_redraw()


## Right-click: if clicking the selected system, zoom to system view; else order ships to the clicked system.
func _handle_right_click_galaxy(screen_pos: Vector2) -> void:
	var target_id: int = _get_hover_system_id_at(screen_pos)
	var source_id: int = GameState.selected_system_id
	if target_id < 0 or GalaxyManager == null:
		return
	# Right-click on the selected system = open system view (replaces View System button).
	if target_id == source_id:
		get_tree().change_scene_to_file(ProjectPaths.SCENE_SOLAR_SYSTEM_VIEW)
		return
	_try_order_ships_to_system_at(screen_pos)


## Order filtered player ships in selected system to the clicked system (pathfind if not neighbor).
func _try_order_ships_to_system_at(screen_pos: Vector2) -> void:
	var target_id: int = _get_hover_system_id_at(screen_pos)
	var source_id: int = GameState.selected_system_id
	if source_id < 0 or target_id < 0 or target_id == source_id or GalaxyManager == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var ships_here: Array = _get_ships_in_system_filtered(source_id, _galaxy_ship_filter)
	if ships_here.is_empty():
		return
	var neighbors: Array[StarSystem] = GalaxyManager.get_system_neighbors(source_id)
	var target_is_neighbor: bool = false
	for nb in neighbors:
		if nb.id == target_id:
			target_is_neighbor = true
			break
	if target_is_neighbor:
		for ship in ships_here:
			var s: Ship = ship as Ship
			if s != null:
				s.target_system_id = target_id
				s.path_queue.clear()
				s.target_position = Vector2(-99999.0, -99999.0)
				s.in_hyperlane = false
				s.hyperlane_to_system_id = -1
				s.hyperlane_progress = 0.0
	else:
		var path: Array[int] = GalaxyManager.get_path_between_systems(source_id, target_id)
		if path.size() < 2:
			return
		var path_rest: Array[int] = []
		for i in range(2, path.size()):
			path_rest.append(path[i])
		for ship in ships_here:
			var s: Ship = ship as Ship
			if s != null:
				s.target_system_id = path[1]
				s.path_queue = path_rest.duplicate()
				s.target_position = Vector2(-99999.0, -99999.0)
				s.in_hyperlane = false
				s.hyperlane_to_system_id = -1
				s.hyperlane_progress = 0.0
	_update_selected_panel()
	for c in systems_layer.get_children():
		c.queue_redraw()


func _get_ships_in_system(system_id: int) -> Array:
	return _get_ships_in_system_filtered(system_id, "all")


func _get_ships_in_system_filtered(system_id: int, filter_type: String) -> Array:
	if filter_type == "station":
		return []
	var out: Array = []
	if EmpireManager == null:
		return out
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return out
	for s in player_emp.ships:
		var ship: Ship = s as Ship
		if ship == null or ship.system_id != system_id or ship.in_hyperlane:
			continue
		if filter_type == "all":
			out.append(ship)
			continue
		var display_type: String = "construction"
		if EconomyManager != null:
			display_type = EconomyManager.get_ship_display_type(ship.design_id)
		if display_type == filter_type:
			out.append(ship)
	return out


func _get_ships_order_status(system_id: int, filter_type: String) -> String:
	if filter_type == "station":
		return "Stations"
	var ships: Array = _get_ships_in_system_filtered(system_id, filter_type)
	if ships.is_empty():
		return "No ships"
	var first: Ship = ships[0] as Ship
	if first == null:
		return "No orders"
	if first.in_hyperlane:
		var to_sys: StarSystem = GalaxyManager.get_system(first.hyperlane_to_system_id) if GalaxyManager != null else null
		return "In transit to %s" % (to_sys.name_key if to_sys != null else "?")
	if first.target_system_id >= 0:
		var to_sys: StarSystem = GalaxyManager.get_system(first.target_system_id) if GalaxyManager != null else null
		return "Moving to %s" % (to_sys.name_key if to_sys != null else "?")
	return "No orders"


func _get_ship_counts_by_type(system_id: int) -> Dictionary:
	var counts: Dictionary = { "all": 0, "science": 0, "construction": 0, "military": 0 }
	var all_ships: Array = _get_ships_in_system_filtered(system_id, "all")
	counts.all = all_ships.size()
	for s in all_ships:
		var ship: Ship = s as Ship
		if ship == null:
			continue
		var display_type: String = "construction"
		if EconomyManager != null:
			display_type = EconomyManager.get_ship_display_type(ship.design_id)
		if display_type == "science":
			counts.science += 1
		elif display_type == "military":
			counts.military += 1
		else:
			counts.construction += 1
	return counts


func _get_hover_system_id_at(screen_pos: Vector2) -> int:
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var best_id := -1
	var best_dist := _click_max_distance()
	for s in GalaxyManager.get_all_systems():
		var d := world_pos.distance_to(s.position)
		if d < best_dist:
			best_dist = d
			best_id = s.id
	return best_id


## Returns "science" | "construction" | "military" | "station" if world_pos hits that indicator, "" otherwise.
func _get_ship_indicator_at(system_id: int, world_pos: Vector2) -> String:
	var sys: StarSystem = GalaxyManager.get_system(system_id) if GalaxyManager != null else null
	if sys == null:
		return ""
	var local: Vector2 = world_pos - sys.position
	var base_y: float = _star_radius_for_indicators() + _indicator_y_offset()
	var dx: float = _indicator_dx()
	var counts: Dictionary = _get_ship_counts_by_type(system_id)
	var station_count: int = 0
	if EmpireManager != null:
		var player_emp: Empire = EmpireManager.get_player_empire()
		if player_emp != null:
			station_count = player_emp.get_stations_in_system(system_id).size()
	# Science circle at (-1.5*dx, base_y)
	if counts.get("science", 0) > 0:
		if local.distance_to(Vector2(-1.5 * dx, base_y)) <= _indicator_size():
			return "science"
	# Construction square
	if counts.get("construction", 0) > 0:
		var cx: float = -0.5 * dx
		var isz: float = _indicator_size()
		if local.x >= cx - isz and local.x <= cx + isz and local.y >= base_y - isz and local.y <= base_y + isz:
			return "construction"
	# Military triangle
	if counts.get("military", 0) > 0:
		var isz: float = _indicator_size()
		var tri: PackedVector2Array = [Vector2(0.5 * dx, base_y - isz), Vector2(0.5 * dx - isz, base_y + isz), Vector2(0.5 * dx + isz, base_y + isz)]
		if Geometry2D.is_point_in_polygon(local, tri):
			return "military"
	# Station diamond
	if station_count > 0:
		var isz: float = _indicator_size()
		var diamond: PackedVector2Array = [Vector2(1.5 * dx, base_y), Vector2(1.5 * dx + isz, base_y + isz), Vector2(1.5 * dx, base_y + isz * 2.0), Vector2(1.5 * dx - isz, base_y + isz)]
		if Geometry2D.is_point_in_polygon(local, diamond):
			return "station"
	return ""


func _setup_hover_tooltip() -> void:
	if overlay_layer == null:
		return
	var script_tooltip: GDScript = preload("res://ui/components/hover_tooltip.gd") as GDScript
	_hover_tooltip = PanelContainer.new()
	_hover_tooltip.set_script(script_tooltip)
	_hover_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_layer.add_child(_hover_tooltip)


func _on_resource_row_entered(res_type: int) -> void:
	_resource_hover_type = res_type


func _on_resource_row_exited() -> void:
	_resource_hover_type = -1


func _update_hover_tooltip(delta: float) -> void:
	if _hover_tooltip == null:
		return
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	if _resource_hover_type >= 0:
		var name_str: String = GameResources.RESOURCE_NAMES.get(_resource_hover_type, "?")
		var desc: String = GameResources.RESOURCE_DESCRIPTIONS.get(_resource_hover_type, "")
		if _hover_tooltip.has_method("show_tooltip"):
			_hover_tooltip.show_tooltip(name_str, desc, screen_pos)
		return
	var sys_id: int = _get_hover_system_id_at(screen_pos)
	if sys_id < 0:
		_hover_accumulator = 0.0
		_hover_last_system_id = -2
		_hover_last_indicator = ""
		if _hover_tooltip.has_method("hide_tooltip"):
			_hover_tooltip.hide_tooltip()
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var indicator: String = _get_ship_indicator_at(sys_id, world_pos)
	if sys_id != _hover_last_system_id or indicator != _hover_last_indicator:
		_hover_accumulator = 0.0
		_hover_last_system_id = sys_id
		_hover_last_indicator = indicator
	_hover_accumulator += delta
	if _hover_accumulator < _hover_delay_seconds():
		return
	var sys: StarSystem = GalaxyManager.get_system(sys_id)
	if sys == null or not _hover_tooltip.has_method("show_tooltip"):
		return
	var body: String = ""
	# Show indicator-specific tooltip when hovering over ship/station icons.
	if not indicator.is_empty():
		var counts: Dictionary = _get_ship_counts_by_type(sys_id)
		var station_count: int = 0
		if EmpireManager != null:
			var player_emp: Empire = EmpireManager.get_player_empire()
			if player_emp != null:
				station_count = player_emp.get_stations_in_system(sys_id).size()
		var title: String = ""
		match indicator:
			"science":
				var n: int = counts.get("science", 0)
				title = "Science ships"
				body = "%d science ship%s in this system" % [n, "s" if n != 1 else ""]
			"construction":
				var n: int = counts.get("construction", 0)
				title = "Construction ships"
				body = "%d construction ship%s in this system" % [n, "s" if n != 1 else ""]
			"military":
				var n: int = counts.get("military", 0)
				title = "Military ships"
				body = "%d military ship%s in this system" % [n, "s" if n != 1 else ""]
			"station":
				title = "Stations"
				body = "%d station%s in this system" % [station_count, "s" if station_count != 1 else ""]
		if not title.is_empty():
			_hover_tooltip.show_tooltip(title, body, screen_pos)
			return
	body = "%d planets, %d asteroid belts" % [sys.planets.size(), sys.asteroid_belts.size()]
	_hover_tooltip.show_tooltip(sys.name_key, body, screen_pos)


func _set_zoom(z: float) -> void:
	_zoom_level = clampf(z, _min_zoom(), _max_zoom())
	camera.zoom = Vector2(_zoom_level, _zoom_level)


func _on_system_selected(_system_id: int) -> void:
	_update_selected_panel()
	for c in systems_layer.get_children():
		if c.get_meta("system_id", -1) == GameState.selected_system_id:
			c.set_meta("highlighted_indicator", _galaxy_selected_indicator)
		else:
			c.set_meta("highlighted_indicator", "")
		c.queue_redraw()


func _setup_send_ships_container() -> void:
	if selected_panel_vbox == null:
		return
	var th: UIThemeOverrides = _ui_theme()
	var sep: int = th.panel_vbox_separation if th != null else 4
	_send_ships_container = VBoxContainer.new()
	_send_ships_container.add_theme_constant_override("separation", sep)
	_send_ships_container.name = "SendShipsContainer"
	selected_panel_vbox.add_child(_send_ships_container)
	_station_buttons_container = VBoxContainer.new()
	_station_buttons_container.add_theme_constant_override("separation", sep)
	_station_buttons_container.name = "StationButtonsContainer"
	selected_panel_vbox.add_child(_station_buttons_container)


func _update_selected_panel() -> void:
	if selected_label == null:
		return
	var id := GameState.selected_system_id
	if _send_ships_container != null:
		for c in _send_ships_container.get_children():
			c.queue_free()
	if _station_buttons_container != null:
		for c in _station_buttons_container.get_children():
			c.queue_free()
	if id < 0:
		selected_panel.visible = false
		return
	var s: StarSystem = GalaxyManager.get_system(id)
	if s == null:
		selected_label.text = "Unknown system"
		if view_system_button != null:
			view_system_button.visible = false
		if survey_button != null:
			survey_button.visible = false
		return
	var colony_text: String = ""
	var first_colony: Colony = null
	var ships_text: String = ""
	var ship_counts: Dictionary = _get_ship_counts_by_type(id)
	var total_ships: int = ship_counts.all
	if total_ships > 0:
		ships_text = "\nShips: %d (right-click connected system to move)" % total_ships
	if EmpireManager != null:
		var player_emp: Empire = EmpireManager.get_player_empire()
		if player_emp != null:
			for col in player_emp.colonies:
				if col.system_id == id:
					colony_text = "\nColony: %d pops" % col.pop_count
					first_colony = col
					break
	if manage_colony_button != null:
		manage_colony_button.visible = (first_colony != null)
		if first_colony != null:
			manage_colony_button.set_meta("colony", first_colony)
	var stations_in_system: Array = []
	if EmpireManager != null:
		var player_emp: Empire = EmpireManager.get_player_empire()
		if player_emp != null:
			stations_in_system = player_emp.get_stations_in_system(id)
	ship_counts["station"] = stations_in_system.size()
	if manage_station_button != null:
		if stations_in_system.size() == 1:
			manage_station_button.visible = true
			manage_station_button.set_meta("station", stations_in_system[0])
		elif stations_in_system.size() > 1:
			manage_station_button.visible = false
			if _station_buttons_container != null:
				var th: UIThemeOverrides = _ui_theme()
				var st_lbl: Label = Label.new()
				st_lbl.text = "Stations:"
				st_lbl.add_theme_font_size_override("font_size", th.panel_label_font_size_medium if th != null else 12)
				st_lbl.add_theme_color_override("font_color", th.panel_label_color_secondary if th != null else Color(0.85, 0.88, 0.95))
				_station_buttons_container.add_child(st_lbl)
				for st in stations_in_system:
					var station: SpaceStation = st as SpaceStation
					if station == null:
						continue
					var btn: Button = Button.new()
					btn.text = "Manage: %s" % station.name_key
					btn.pressed.connect(_on_manage_station_pressed.bind(station))
					_station_buttons_container.add_child(btn)
		else:
			manage_station_button.visible = false
	var anomaly_text: String = ""
	if PrecursorManager != null and survey_button != null:
		var uns: Anomaly = PrecursorManager.get_unsurveyed_anomaly_in_system(id)
		survey_button.visible = (uns != null)
		if uns != null:
			anomaly_text = "\nPrecursor anomaly (unsurveyed)"
	elif survey_button != null:
		survey_button.visible = false
	var fe_text: String = ""
	if GalaxyManager != null and GalaxyManager.galaxy != null:
		for fe in GalaxyManager.galaxy.fallen_empires:
			if fe.owns_system(id):
				fe_text = "\nFallen Empire: %s (do not provoke)" % fe.name_key
				break
	var star_name: String = StarSystem.StarType.keys()[s.star_type] if s.star_type >= 0 else "?"
	var view_hint: String = "\nRight-click system to open system view." if total_ships == 0 else ""
	selected_label.text = "%s\nStar: %s\nPlanets: %d%s%s%s%s%s" % [s.name_key, star_name, s.planets.size(), colony_text, ships_text, anomaly_text, fe_text, view_hint]
	if view_system_button != null:
		view_system_button.visible = false  # Replaced by right-click on system to open system view
	selected_panel.visible = true
	# Ship/station information section + filter when there are ships or stations in this system
	if _send_ships_container != null and (total_ships > 0 or stations_in_system.size() > 0) and GalaxyManager != null:
		# Ships info header (Stellaris-style selection window)
		var th: UIThemeOverrides = _ui_theme()
		var ships_header: Label = Label.new()
		ships_header.text = "——— Ships in %s ———" % s.name_key
		ships_header.add_theme_font_size_override("font_size", th.panel_label_font_size_large if th != null else 13)
		ships_header.add_theme_color_override("font_color", th.panel_label_color_primary if th != null else Color(0.9, 0.92, 1.0))
		_send_ships_container.add_child(ships_header)
		var counts_line: Label = Label.new()
		var type_parts: Array[String] = []
		if ship_counts.science > 0:
			type_parts.append("Science: %d" % ship_counts.science)
		if ship_counts.construction > 0:
			type_parts.append("Construction: %d" % ship_counts.construction)
		if ship_counts.military > 0:
			type_parts.append("Military: %d" % ship_counts.military)
		if ship_counts.get("station", 0) > 0:
			type_parts.append("Stations: %d" % ship_counts.get("station", 0))
		counts_line.text = ", ".join(type_parts) if type_parts.size() > 0 else ("Stations: %d" % stations_in_system.size() if total_ships == 0 else "Ships: %d" % total_ships)
		counts_line.add_theme_font_size_override("font_size", th.panel_label_font_size_medium if th != null else 12)
		counts_line.add_theme_color_override("font_color", th.panel_label_color_muted if th != null else Color(0.8, 0.85, 0.95))
		_send_ships_container.add_child(counts_line)
		var filtered_count: int = stations_in_system.size() if _galaxy_ship_filter == "station" else _get_ships_in_system_filtered(id, _galaxy_ship_filter).size()
		var status_line: Label = Label.new()
		var order_status: String = _get_ships_order_status(id, _galaxy_ship_filter)
		status_line.text = "Selected: %s (%d)  |  %s" % [_galaxy_ship_filter.capitalize(), filtered_count, order_status]
		status_line.add_theme_font_size_override("font_size", th.panel_label_font_size_small if th != null else 11)
		status_line.add_theme_color_override("font_color", th.panel_label_color_tertiary if th != null else Color(0.7, 0.78, 0.9))
		_send_ships_container.add_child(status_line)
		# Row: "Move: [All (N)] [Science (n)] [Construction (n)] [Military (n)]"
		var filter_lbl: Label = Label.new()
		filter_lbl.text = "Move:"
		filter_lbl.add_theme_font_size_override("font_size", th.panel_label_font_size_medium if th != null else 12)
		filter_lbl.add_theme_color_override("font_color", th.panel_label_color_secondary if th != null else Color(0.85, 0.88, 0.95))
		_send_ships_container.add_child(filter_lbl)
		var filter_row: HBoxContainer = HBoxContainer.new()
		filter_row.add_theme_constant_override("separation", th.panel_hbox_separation if th != null else 6)
		var filter_keys: Array[String] = ["all", "science", "construction", "military"]
		if ship_counts.get("station", 0) > 0:
			filter_keys.append("station")
		for filter_key in filter_keys:
			var count: int = ship_counts.get(filter_key, 0)
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.button_pressed = (_galaxy_ship_filter == filter_key)
			var label: String = filter_key.capitalize()
			btn.text = "%s (%d)" % [label, count]
			btn.disabled = count == 0
			if count > 0:
				btn.pressed.connect(_on_ship_filter_pressed.bind(filter_key))
			filter_row.add_child(btn)
		_send_ships_container.add_child(filter_row)
	_resource_strip_controller.update_resource_display()


func _apply_ui_canvas_styles() -> void:
	if get_tree().root.theme != null:
		ui_canvas.theme = get_tree().root.theme
	var th: UIThemeOverrides = _ui_theme()
	# Top bar
	var bar_bg: Color = th.bar_bg_color if th != null else Color(0.02, 0.04, 0.07, 0.97)
	var bar_border: Color = th.bar_border_color if th != null else Color(0.12, 0.23, 0.37, 1.0)
	var bar_h: float = th.bar_height if th != null else 28.0
	var res_label_col: Color = th.resource_label_color if th != null else Color(0.35, 0.55, 0.72, 1.0)
	var res_value_col: Color = th.resource_value_color if th != null else Color(0.78, 0.91, 1.0, 1.0)
	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = bar_bg
	top_style.set_border_width_all(0)
	top_style.border_width_bottom = 1
	top_style.border_color = bar_border
	top_bar.add_theme_stylebox_override("panel", top_style)
	top_bar.custom_minimum_size.y = int(bar_h)
	if date_label != null:
		date_label.add_theme_color_override("font_color", res_label_col)
		date_label.add_theme_font_size_override("font_size", th.bar_date_font_size if th != null else 18)
	# Sidebar
	var side_bg: Color = th.sidebar_bg_color if th != null else Color(0.02, 0.03, 0.06, 0.97)
	var side_w: float = th.sidebar_width if th != null else 52.0
	var item_col: Color = th.item_text_color if th != null else Color(0.25, 0.48, 0.65, 1.0)
	var item_hover: Color = th.item_hover_color if th != null else Color(0.45, 0.68, 0.88, 1.0)
	var item_active: Color = th.item_active_color if th != null else Color(0.78, 0.91, 1.0, 1.0)
	var accent: Color = th.item_active_accent if th != null else Color(0.29, 0.55, 0.77, 1.0)
	var side_style: StyleBoxFlat = StyleBoxFlat.new()
	side_style.bg_color = side_bg
	side_style.set_border_width_all(0)
	side_style.border_width_right = 1
	side_style.border_color = bar_border
	nav_strip.add_theme_stylebox_override("panel", side_style)
	nav_strip.custom_minimum_size.x = int(side_w)
	var nav_vbox: VBoxContainer = nav_strip.get_node_or_null("MarginContainer/VBox") as VBoxContainer
	if nav_vbox != null:
		for c in nav_vbox.get_children():
			if c is Button:
				var btn: Button = c as Button
				btn.flat = true
				btn.add_theme_color_override("font_color", item_col)
				btn.add_theme_color_override("font_hover_color", item_hover)
	# Date/speed: pause + scale buttons flat; active gets accent in _update_speed_buttons
	pause_button.flat = true
	for sb in _scale_buttons:
		if sb != null:
			sb.flat = true
			sb.add_theme_color_override("font_color", item_col)
			sb.add_theme_color_override("font_hover_color", item_hover)
	pause_button.add_theme_color_override("font_color", item_col)
	pause_button.add_theme_color_override("font_hover_color", item_hover)
	# Music player panel: same panel style as sidebar, same button colors
	if music_player_panel != null:
		var music_panel_style: StyleBoxFlat = StyleBoxFlat.new()
		music_panel_style.bg_color = side_bg
		music_panel_style.set_border_width_all(0)
		music_panel_style.border_width_left = 1
		music_panel_style.border_color = bar_border
		music_player_panel.add_theme_stylebox_override("panel", music_panel_style)
		for btn in [music_play_button, music_pause_button, music_next_button]:
			if btn != null:
				btn.flat = true
				btn.add_theme_color_override("font_color", item_col)
				btn.add_theme_color_override("font_hover_color", item_hover)
	_update_speed_buttons()


func _on_music_playback_state_changed(playing: bool) -> void:
	if music_play_button != null:
		music_play_button.visible = not playing
	if music_pause_button != null:
		music_pause_button.visible = playing


func _on_music_volume_changed(value: float) -> void:
	if MusicPlayer != null:
		MusicPlayer.set_volume_linear(value)


func _format_scale_label(scale: float) -> String:
	if scale == int(scale):
		return str(int(scale)) + "x"
	return str(scale).trim_prefix("0") + "x"


func _build_scale_buttons() -> void:
	if scale_buttons_container == null or GameState == null:
		return
	for c in scale_buttons_container.get_children():
		c.queue_free()
	_scale_buttons.clear()
	for scale in GameState.available_scales:
		var s: float = scale as float
		var btn: Button = Button.new()
		btn.text = _format_scale_label(s)
		btn.flat = true
		btn.pressed.connect(_on_scale_pressed.bind(s))
		scale_buttons_container.add_child(btn)
		_scale_buttons.append(btn)
	_update_speed_buttons()


func _on_scale_pressed(scale: float) -> void:
	GameState.set_time_scale(scale)


func _on_pause_state_changed(is_paused: bool) -> void:
	if pause_button != null:
		pause_button.text = "Resume" if is_paused else "Pause"


func _update_speed_buttons(_new_speed: int = 0) -> void:
	pause_button.button_pressed = GameState.is_paused()
	pause_button.text = "Resume" if GameState.is_paused() else "Pause"
	var th: UIThemeOverrides = _ui_theme()
	var accent: Color = th.item_active_accent if th != null else Color(0.29, 0.55, 0.77, 1.0)
	var item_active: Color = th.item_active_color if th != null else Color(0.78, 0.91, 1.0, 1.0)
	var item_text: Color = th.item_text_color if th != null else Color(0.25, 0.48, 0.65, 1.0)
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.02, 0.03, 0.06, 0.0)
	normal_style.set_border_width_all(0)
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0.08, 0.12, 0.18, 0.6)
	active_style.set_border_width_all(0)
	active_style.border_width_left = 3
	active_style.border_color = accent
	for sb in _scale_buttons:
		if sb == null:
			continue
		sb.add_theme_stylebox_override("normal", normal_style.duplicate())
		sb.add_theme_stylebox_override("hover", normal_style.duplicate())
		sb.add_theme_stylebox_override("pressed", normal_style.duplicate())
		sb.add_theme_color_override("font_color", item_text)
	var active_btn: Button = null
	if GameState.is_paused():
		active_btn = pause_button
	else:
		for i in _scale_buttons.size():
			if i < GameState.available_scales.size() and GameState.game_speed == i + 1:
				active_btn = _scale_buttons[i]
				break
	if active_btn != null:
		active_btn.add_theme_stylebox_override("normal", active_style)
		active_btn.add_theme_color_override("font_color", item_active)
	for sb in _scale_buttons:
		if sb != null and sb != active_btn:
			sb.add_theme_color_override("font_color", item_text)
	if pause_button != active_btn:
		pause_button.add_theme_color_override("font_color", item_text)
	else:
		pause_button.add_theme_color_override("font_color", item_active)


func _on_pause_toggled(paused: bool) -> void:
	GameState.set_game_speed(0 if paused else 4)
	_update_speed_buttons()


func _on_view_system_pressed() -> void:
	if GameState.selected_system_id >= 0:
		get_tree().change_scene_to_file(ProjectPaths.SCENE_SOLAR_SYSTEM_VIEW)


func _on_ship_filter_pressed(filter_key: String) -> void:
	_galaxy_ship_filter = filter_key
	_galaxy_selected_indicator = "" if filter_key == "all" else filter_key
	for c in systems_layer.get_children():
		if c.get_meta("system_id", -1) == GameState.selected_system_id:
			c.set_meta("highlighted_indicator", _galaxy_selected_indicator)
		c.queue_redraw()
	_update_selected_panel()


func _on_send_ships_to_neighbor_pressed(neighbor_system_id: int) -> void:
	var source_id: int = GameState.selected_system_id
	if source_id < 0 or EmpireManager == null:
		return
	var ships_here: Array = _get_ships_in_system_filtered(source_id, _galaxy_ship_filter)
	if ships_here.is_empty():
		return
	for ship in ships_here:
		var s: Ship = ship as Ship
		if s != null:
			s.target_system_id = neighbor_system_id
			s.path_queue.clear()
			s.target_position = Vector2(-99999.0, -99999.0)
			s.in_hyperlane = false
			s.hyperlane_to_system_id = -1
			s.hyperlane_progress = 0.0
	_update_selected_panel()
	for c in systems_layer.get_children():
		c.queue_redraw()


func _on_manage_station_pressed(bound_station: Variant = null) -> void:
	var station: Variant = bound_station if bound_station is SpaceStation else manage_station_button.get_meta("station", null)
	if station is SpaceStation and EmpireManager != null:
		var player_emp: Empire = EmpireManager.get_player_empire()
		if player_emp != null:
			_open_station_window(station as SpaceStation, player_emp)


func _open_station_window(station: SpaceStation, empire: Empire) -> void:
	var win: Control = _instantiate_overlay(overlay_space_station, ProjectPaths.SCENE_SPACE_STATION_WINDOW) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), win, _overlay_rect("station"), false, false)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if win.has_method("setup"):
		win.setup(station, empire)
	if win.has_signal("closed"):
		win.closed.connect(_on_station_window_closed.bind(container))
	if win.has_signal("open_ship_designer_requested"):
		win.open_ship_designer_requested.connect(_open_ship_designer_overlay)
	overlay_layer.add_child(container)


func _on_station_window_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_update_selected_panel()
	_resource_strip_controller.update_resource_display()


func _on_ship_designer_pressed() -> void:
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp != null:
		_open_ship_designer_overlay(player_emp)


func _open_ship_designer_overlay(empire: Empire) -> void:
	var designer: Control = _instantiate_overlay(overlay_ship_designer, ProjectPaths.SCENE_SHIP_DESIGNER_WINDOW) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), designer, _overlay_rect("ship_designer"), false, false)
	overlay_layer.add_child(container)
	if designer.has_method("setup"):
		designer.setup(empire)
	if designer.has_signal("closed"):
		designer.closed.connect(_on_ship_designer_closed.bind(container))


func _on_ship_designer_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_resource_strip_controller.update_resource_display()


func _on_manage_colony_pressed() -> void:
	var col: Variant = manage_colony_button.get_meta("colony", null)
	if col is Colony:
		GameState.selected_colony_system_id = col.system_id
		GameState.selected_colony_planet_index = col.planet_index
		GameState.planet_view_return_scene = ProjectPaths.SCENE_GAME_SCENE
		_open_planet_view_overlay()


func _on_planets_pressed() -> void:
	_open_colonies_overlay()


func _on_technology_pressed() -> void:
	_open_technology_overlay()


func _on_tech_tree_pressed() -> void:
	_open_tech_tree_overlay()


func _on_leaders_pressed() -> void:
	_open_leaders_overlay()


func _open_colonies_overlay() -> void:
	var colonies: Control = _instantiate_overlay(overlay_colonies, ProjectPaths.SCENE_COLONIES_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), colonies, _overlay_rect("colonies"), false, false)
	colonies.set_manage_callback(func(sid: int, pidx: int) -> void:
		GameState.selected_colony_system_id = sid
		GameState.selected_colony_planet_index = pidx
		GameState.planet_view_return_scene = ProjectPaths.SCENE_GAME_SCENE
		if is_instance_valid(container):
			container.queue_free()
		_open_planet_view_overlay()
	)
	if colonies.has_signal("closed"):
		colonies.closed.connect(_on_generic_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _open_technology_overlay() -> void:
	var tech: Control = _instantiate_overlay(overlay_technology, ProjectPaths.SCENE_TECHNOLOGY_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), tech, _overlay_rect("technology"), false, false)
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp != null and tech.has_method("setup"):
		tech.setup(player_emp)
	if tech.has_signal("closed"):
		tech.closed.connect(_on_generic_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _open_tech_tree_overlay() -> void:
	var prev_speed: int = GameState.game_speed
	GameState.set_game_speed(0)
	var tech_tree: Control = _instantiate_overlay(overlay_tech_tree, ProjectPaths.SCENE_TECH_TREE) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), tech_tree, Vector4.ZERO, true, false)
	if tech_tree.has_signal("closed"):
		tech_tree.closed.connect(_on_tech_tree_overlay_closed.bind(container, prev_speed))
	overlay_layer.add_child(container)
	_update_speed_buttons()


func _open_leaders_overlay() -> void:
	var leaders: Control = _instantiate_overlay(overlay_leaders, ProjectPaths.SCENE_LEADERS_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), leaders, _overlay_rect("leaders"), false, false)
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp != null and leaders.has_method("setup"):
		leaders.setup(player_emp)
	if leaders.has_signal("closed"):
		leaders.closed.connect(_on_generic_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _on_generic_overlay_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_resource_strip_controller.update_resource_display()
	_research_panel_controller.update_research_panel()


func _on_tech_tree_overlay_closed(overlay_container: Control, prev_speed: int) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	GameState.set_game_speed(prev_speed)
	_update_speed_buttons()
	_resource_strip_controller.update_resource_display()
	_research_panel_controller.update_research_panel()


func _open_planet_view_overlay() -> void:
	var pv: Control = _instantiate_overlay(overlay_planet_view, ProjectPaths.SCENE_PLANET_VIEW) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), pv, _overlay_rect("planet_view"), false, false)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pv.has_signal("closed"):
		pv.closed.connect(_on_planet_view_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _on_planet_view_overlay_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_resource_strip_controller.update_resource_display()


func _on_tech_draw_1_pressed() -> void:
	if _research_panel_controller != null and _research_panel_controller.pick_tech_from_draw(0):
		_research_panel_controller.update_research_panel()


func _on_tech_draw_2_pressed() -> void:
	if _research_panel_controller != null and _research_panel_controller.pick_tech_from_draw(1):
		_research_panel_controller.update_research_panel()


func _on_tech_draw_3_pressed() -> void:
	if _research_panel_controller != null and _research_panel_controller.pick_tech_from_draw(2):
		_research_panel_controller.update_research_panel()


func _on_survey_pressed() -> void:
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp == null or PrecursorManager == null or GameState.selected_system_id < 0:
		return
	var anomaly: Anomaly = PrecursorManager.get_unsurveyed_anomaly_in_system(GameState.selected_system_id)
	if anomaly != null:
		PrecursorManager.survey_anomaly(player_emp, anomaly)
		_update_selected_panel()
