extends Node2D
## Displays a single star system: star at center, planets, asteroid belts.
## Click star/planet/belt to show info panel.

## Optional: assign a GameplayConfig resource to tune time, zoom, and layout in the inspector.
@export var gameplay_config: GameplayConfig = null
## Overlay scenes (assign in inspector to swap or test; empty = use built-in preload).
@export var overlay_colonies: PackedScene = null
@export var overlay_technology: PackedScene = null
@export var overlay_tech_tree: PackedScene = null
@export var overlay_leaders: PackedScene = null
@export var overlay_government: PackedScene = null
@export var overlay_planet_view: PackedScene = null
@export var overlay_space_station: PackedScene = null
@export var overlay_ship_designer: PackedScene = null
## Optional: tune star/planet colors and station/ship click radii in the inspector.
@export var system_view_palette: SystemViewPalette = null
## When true, lives under game_scene; Back returns to galaxy without scene swap.
@export var embedded_in_game_scene: bool = false

enum SelectedType { NONE, STAR, PLANET, BELT, STATION, SHIP }

@onready var camera: Camera2D = $Camera2D
@onready var system_content: Node2D = $SystemContent
@onready var star_node: Node2D = $SystemContent/StarNode
@onready var belts_node: Node2D = $SystemContent/BeltsNode
@onready var orbits_node: Node2D = $SystemContent/OrbitsNode
@onready var planets_node: Node2D = $SystemContent/PlanetsNode
@onready var stations_node: Node2D = $SystemContent/StationsNode
@onready var ships_node: Node2D = $SystemContent/ShipsNode
@onready var title_label: Label = $UICanvas/TopBar/MarginContainer/VBox/Row1/TitleLabel
@onready var back_button: Button = $UICanvas/TopBar/MarginContainer/VBox/Row1/BackButton
@onready var resource_strip_line1: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row1/ResourceLine1
@onready var resource_strip_line2: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row2/ResourceLine2
@onready var top_bar_vbox: VBoxContainer = $UICanvas/TopBar/MarginContainer/VBox
@onready var date_label: Label = $UICanvas/TopBar/MarginContainer/VBox/Row1/DateLabel
@onready var pause_button: Button = $UICanvas/TopBar/MarginContainer/VBox/Row1/PauseButton
@onready var scale_buttons_container: HBoxContainer = $UICanvas/TopBar/MarginContainer/VBox/Row1/ScaleButtonsContainer
@onready var info_panel: PanelContainer = $UICanvas/InfoPanel
var _ships_selected_label: Label = null  # Created in _ready
@onready var info_title: Label = $UICanvas/InfoPanel/MarginContainer/VBox/InfoTitle
@onready var info_text: Label = $UICanvas/InfoPanel/MarginContainer/VBox/InfoText
@onready var manage_colony_button: Button = $UICanvas/InfoPanel/MarginContainer/VBox/ManageColonyButton
@onready var manage_station_button: Button = $UICanvas/InfoPanel/MarginContainer/VBox/ManageStationButton
@onready var overlay_layer: CanvasLayer = $OverlayLayer
@onready var planets_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/PlanetsButton
@onready var technology_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/TechnologyButton
@onready var tech_tree_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/TechTreeButton
@onready var leaders_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/LeadersButton
@onready var government_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/GovernmentButton
@onready var ship_designer_button: Button = $UICanvas/NavStrip/MarginContainer/VBox/ShipDesignerButton
@onready var ui_canvas: CanvasLayer = $UICanvas
@onready var top_bar: PanelContainer = $UICanvas/TopBar
@onready var nav_strip: PanelContainer = $UICanvas/NavStrip
@onready var music_player_panel: PanelContainer = $UICanvas/MusicPlayerPanel
@onready var music_play_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicPlayButton
@onready var music_pause_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicPauseButton
@onready var music_next_button: Button = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicNextButton
@onready var music_volume_slider: HSlider = $UICanvas/MusicPlayerPanel/MarginContainer/HBox/MusicVolumeSlider

var _current_system: StarSystem
var _selected_type: SelectedType = SelectedType.NONE
var _selected_planet: Planet = null
var _selected_belt: AsteroidBelt = null
var _selected_station = null  ## SpaceStation or ResourceStation
var _selected_ships: Array = []  # Array of Ship (click or drag select)
var _planet_nodes: Array[Node2D] = []  # parallel to system.planets for click lookup
var _station_nodes: Array[Node2D] = []  # parallel to station positions for click lookup
var _ship_nodes: Array[Node2D] = []  # parallel to ship nodes for click/drag select
var _zoom_level: float = 1.5
var _panning: bool = false  # middle mouse camera pan
var _drag_start: Vector2
var _select_dragging: bool = false  # left mouse drag selection
var _select_drag_start: Vector2
var _select_drag_end: Vector2
var _selection_rect: ColorRect = null  # overlay for drag-select box
var _day_accumulator: float = 0.0
var _hover_tooltip: Control = null
var _hover_accumulator: float = 0.0
var _hover_last_id: String = ""  # "star"|"planet:0"|"belt:0"|"station:0"|"ship:0" to avoid flicker
var _resource_hover_type: int = -1  # GameResources.ResourceType when mouse over a resource row
var _resource_strip_controller: ResourceStripController = null
var _scale_buttons: Array[Button] = []
var _government_overlay_container: Control = null
## Jump markers + boundary + selection paths (child of SystemContent, draw-only).
var _overlay_draw: Node2D = null
## Per-neighbor jump data for hit-test and labels: { "id": int, "name": String, "pos": Vector2 }
var _jump_targets: Array = []

var _ResourceStationScript: GDScript = preload("res://ships/resource_station.gd") as GDScript

const JUMP_RIGHT_CLICK_RADIUS: float = 52.0
const JUMP_MARKER_RADIUS: float = 22.0


func _get_cfg() -> GameplayConfig:
	return gameplay_config


func _seconds_per_day() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.get_seconds_per_day() if c != null else 2.0 / 30.0


func _star_radius() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.star_radius if c != null else 68.0


func _star_click_radius() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.star_click_radius if c != null else 55.0


func _planet_click_radius() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.planet_click_radius if c != null else 18.0


func _zoom_speed() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.system_zoom_speed if c != null else 1.15


func _min_zoom() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.system_min_zoom if c != null else 0.4


func _max_zoom() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.system_max_zoom if c != null else 4.0


func _click_drag_threshold() -> float:
	var c: GameplayConfig = _get_cfg()
	return c.click_drag_threshold if c != null else 6.0


func _instantiate_overlay(export_scene: PackedScene, fallback_path: String) -> Node:
	if export_scene != null:
		return export_scene.instantiate()
	return (load(fallback_path) as PackedScene).instantiate()


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
			"government": return Vector4(-320, -280, 320, 280)
			"planet_view": return Vector4(-675, -540, 675, 540)
			"station": return Vector4(-450, -350, 450, 350)
			"ship_designer": return Vector4(-470, -310, 470, 310)
			_: return Vector4(-300, -200, 300, 200)
	match rect_key:
		"colonies": return c.overlay_colonies_rect
		"technology": return c.overlay_technology_rect
		"leaders": return c.overlay_leaders_rect
		"government": return c.overlay_government_rect
		"planet_view": return c.overlay_planet_view_rect
		"station": return c.overlay_station_rect
		"ship_designer": return c.overlay_ship_designer_rect
		_: return c.overlay_colonies_rect


func _station_click_radius() -> float:
	if system_view_palette != null:
		return system_view_palette.station_click_radius
	return 14.0


func _ship_click_radius() -> float:
	if system_view_palette != null:
		return system_view_palette.ship_click_radius
	return 12.0


func _star_color(star_type: int) -> Color:
	if system_view_palette != null:
		return system_view_palette.get_star_color(star_type)
	return _default_star_color(star_type)


func _planet_color(planet_type: int) -> Color:
	if system_view_palette != null:
		return system_view_palette.get_planet_color(planet_type)
	return _default_planet_color(planet_type)


func _default_star_color(index: int) -> Color:
	var defaults: Array[Color] = [
		Color(0.9, 0.4, 0.2), Color(0.95, 0.6, 0.2), Color(1.0, 0.95, 0.6), Color(1.0, 1.0, 0.9),
		Color(0.95, 0.98, 1.0), Color(0.7, 0.8, 1.0), Color(0.4, 0.5, 1.0), Color(0.1, 0.05, 0.1),
		Color(0.95, 0.98, 1.0), Color(0.98, 0.99, 1.0),
	]
	return defaults[clampi(index, 0, defaults.size() - 1)] if index >= 0 and index < defaults.size() else Color.WHITE


func _default_planet_color(index: int) -> Color:
	var defaults: Array[Color] = [
		Color(0.5, 0.45, 0.4), Color(0.85, 0.7, 0.35), Color(0.7, 0.85, 1.0), Color(0.3, 0.7, 0.35),
		Color(0.35, 0.6, 0.4), Color(0.2, 0.4, 0.8), Color(0.4, 0.85, 0.5), Color(0.9, 0.75, 0.45),
		Color(0.9, 0.35, 0.15), Color(0.95, 0.8, 0.4),
	]
	return defaults[clampi(index, 0, defaults.size() - 1)] if index >= 0 and index < defaults.size() else Color.GRAY


# Right-click context menu
const _MENU_ID_BUILD_MINING_STATION := 0
const _MENU_ID_MOVE_HERE := 1
const _MENU_ID_COLONIZE := 2
var _context_menu: PopupMenu = null
var _pending_world_pos: Vector2 = Vector2.ZERO
var _pending_hover: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	manage_colony_button.pressed.connect(_on_manage_colony_pressed)
	manage_station_button.pressed.connect(_on_manage_station_pressed)
	planets_button.pressed.connect(_on_planets_pressed)
	technology_button.pressed.connect(_on_technology_pressed)
	tech_tree_button.pressed.connect(_on_tech_tree_pressed)
	leaders_button.pressed.connect(_on_leaders_pressed)
	government_button.pressed.connect(_on_government_pressed)
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
	if pause_button != null:
		pause_button.toggled.connect(_on_pause_toggled)
	_build_scale_buttons()
	if EventBus != null:
		EventBus.pause_state_changed.connect(_on_pause_state_changed)
	if GameState != null:
		GameState.game_speed_changed.connect(_update_speed_buttons)
	_resource_strip_controller = ResourceStripController.new()
	_resource_strip_controller.setup(resource_strip_line1, resource_strip_line2, top_bar_vbox, date_label, func(): return _get_cfg().ui_theme if _get_cfg() != null else null, func(): return _get_cfg())
	_resource_strip_controller.resource_row_entered.connect(_on_resource_row_entered)
	_resource_strip_controller.resource_row_exited.connect(_on_resource_row_exited)
	_resource_strip_controller.build_resource_strip()
	_apply_ui_canvas_styles()
	_setup_selection_rect()
	_setup_hover_tooltip()
	_setup_context_menu()
	_ensure_ships_selected_label()
	if ShipMoveOrder != null:
		ShipMoveOrder.apply_gameplay_config(_get_cfg())
	_ensure_overlay_draw()
	if SelectionManager != null:
		SelectionManager.selection_changed.connect(_on_selection_manager_changed)
	if embedded_in_game_scene:
		visible = false
		if EconomyManager != null:
			if EconomyManager.has_signal("ship_built"):
				EconomyManager.ship_built.connect(_on_ship_built)
			if EconomyManager.has_signal("resource_station_built"):
				EconomyManager.resource_station_built.connect(_on_resource_station_built)
		return
	var system_id: int = GameState.selected_system_id
	if system_id < 0:
		title_label.text = "No system selected"
		return
	var sys: StarSystem = GalaxyManager.get_system(system_id)
	if sys == null:
		title_label.text = "Unknown system"
		return
	title_label.text = sys.name_key
	_current_system = sys
	_build_system(sys)
	_update_info_panel()
	_resource_strip_controller.update_resource_display()
	_update_ships_selected_label()
	if EconomyManager != null:
		if EconomyManager.has_signal("ship_built"):
			EconomyManager.ship_built.connect(_on_ship_built)
		if EconomyManager.has_signal("resource_station_built"):
			EconomyManager.resource_station_built.connect(_on_resource_station_built)


func _ensure_ships_selected_label() -> void:
	if _ships_selected_label != null:
		return
	_ships_selected_label = Label.new()
	_ships_selected_label.name = "ShipsSelectedLabel"
	_ships_selected_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	$UICanvas/TopBar/MarginContainer/VBox/Row1.add_child(_ships_selected_label)


func _on_selection_manager_changed(_ships: Array) -> void:
	if not visible or _current_system == null:
		return
	_sync_local_ships_from_selection_manager()
	_update_ship_selection_indicators()


func _clear_system_geometry() -> void:
	for c in belts_node.get_children():
		c.queue_free()
	for c in orbits_node.get_children():
		c.queue_free()
	for c in planets_node.get_children():
		c.queue_free()
	for c in stations_node.get_children():
		c.queue_free()
	for c in ships_node.get_children():
		c.queue_free()
	_planet_nodes.clear()
	_station_nodes.clear()
	_ship_nodes.clear()


## Called from GameScene when opening system view while embedded.
func enter_embedded(system_id: int) -> void:
	if ShipMoveOrder != null:
		ShipMoveOrder.apply_gameplay_config(_get_cfg())
	_clear_system_geometry()
	_selected_type = SelectedType.NONE
	_selected_planet = null
	_selected_belt = null
	_selected_station = null
	_selected_ships.clear()
	GameState.selected_system_id = system_id
	if system_id < 0:
		title_label.text = "No system selected"
		_current_system = null
		return
	var sys: StarSystem = GalaxyManager.get_system(system_id)
	if sys == null:
		title_label.text = "Unknown system"
		_current_system = null
		return
	title_label.text = sys.name_key
	_current_system = sys
	_build_system(sys)
	_update_info_panel()
	_resource_strip_controller.update_resource_display()
	_sync_local_ships_from_selection_manager()
	_update_ship_selection_indicators()
	_update_ships_selected_label()


func _planet_return_scene() -> String:
	return ProjectPaths.SCENE_GAME_SCENE if embedded_in_game_scene else ProjectPaths.SCENE_SOLAR_SYSTEM_VIEW


func _ship_to_selection_data(ship: Ship) -> ShipData:
	var d := ShipData.new()
	if ship == null:
		return d
	d.ship_name = ship.name_key
	d.ship_class = EconomyManager.get_ship_display_type(ship.design_id) if EconomyManager != null else "construction"
	d.galaxy_system_id = ship.system_id
	d.galaxy_empire_id = ship.empire_id
	d.galaxy_selection_instance_id = int(ship.get_instance_id())
	d.transit_time_modifier = ship.transit_time_modifier
	if ship.in_hyperlane:
		d.transit_days_total = ship.hyperlane_transit_days
		d.transit_days_remaining = ceili((1.0 - ship.hyperlane_progress) * float(ship.hyperlane_transit_days))
	return d


func _sync_local_ships_from_selection_manager() -> void:
	_selected_ships.clear()
	if SelectionManager == null or _current_system == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	for sd in SelectionManager.selected_ships:
		for s in player_emp.ships:
			var ship: Ship = s as Ship
			if ship == null or ship.system_id != _current_system.id or ship.in_hyperlane:
				continue
			if sd.matches_ship(ship):
				_selected_ships.append(ship)
				break


func _command_ships_in_current_system() -> Array[Ship]:
	var out: Array[Ship] = []
	if _current_system == null or SelectionManager == null:
		return out
	for ship in SelectionManager.get_selected_live_ships_in_system(_current_system.id):
		out.append(ship as Ship)
	return out


func _apply_ui_canvas_styles() -> void:
	if get_tree().root.theme != null:
		ui_canvas.theme = get_tree().root.theme
	var th: UIThemeOverrides = _get_cfg().ui_theme if _get_cfg() != null else null
	var bar_bg: Color = th.bar_bg_color if th != null else Color(0.02, 0.04, 0.07, 0.97)
	var bar_border: Color = th.bar_border_color if th != null else Color(0.12, 0.23, 0.37, 1.0)
	var bar_h: float = th.bar_height if th != null else 28.0
	var res_label_col: Color = th.resource_label_color if th != null else Color(0.35, 0.55, 0.72, 1.0)
	var side_bg: Color = th.sidebar_bg_color if th != null else Color(0.02, 0.03, 0.06, 0.97)
	var side_w: float = th.sidebar_width if th != null else 52.0
	var item_col: Color = th.item_text_color if th != null else Color(0.25, 0.48, 0.65, 1.0)
	var item_hover: Color = th.item_hover_color if th != null else Color(0.45, 0.68, 0.88, 1.0)
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
	if title_label != null:
		title_label.add_theme_color_override("font_color", res_label_col)
	if back_button != null:
		back_button.flat = true
		back_button.add_theme_color_override("font_color", item_col)
		back_button.add_theme_color_override("font_hover_color", item_hover)
	if pause_button != null:
		pause_button.flat = true
		pause_button.add_theme_color_override("font_color", item_col)
		pause_button.add_theme_color_override("font_hover_color", item_hover)
	for sb in _scale_buttons:
		if sb != null:
			sb.flat = true
			sb.add_theme_color_override("font_color", item_col)
			sb.add_theme_color_override("font_hover_color", item_hover)
	_update_speed_buttons()
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


func _on_pause_state_changed(_is_paused: bool) -> void:
	if pause_button != null:
		pause_button.text = "Resume" if GameState.is_paused() else "Pause"


func _update_speed_buttons(_new_speed: int = 0) -> void:
	if pause_button == null:
		return
	pause_button.button_pressed = GameState.is_paused()
	pause_button.text = "Resume" if GameState.is_paused() else "Pause"
	var th: UIThemeOverrides = _get_cfg().ui_theme if _get_cfg() != null else null
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
	if pause_button != active_btn:
		pause_button.add_theme_color_override("font_color", item_text)
	else:
		pause_button.add_theme_color_override("font_color", item_active)


func _on_pause_toggled(paused: bool) -> void:
	GameState.set_game_speed(0 if paused else 4)
	_update_speed_buttons()


func _setup_selection_rect() -> void:
	_selection_rect = ColorRect.new()
	_selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_rect.color = Color(0.3, 0.6, 1.0, 0.25)
	_selection_rect.visible = false
	_selection_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_layer.add_child(_selection_rect)


func _setup_hover_tooltip() -> void:
	var script_tooltip: GDScript = preload("res://ui/components/hover_tooltip.gd") as GDScript
	_hover_tooltip = PanelContainer.new()
	_hover_tooltip.set_script(script_tooltip)
	_hover_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_layer.add_child(_hover_tooltip)


func _setup_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "ContextMenu"
	overlay_layer.add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _get_hover_at(world_pos: Vector2) -> Dictionary:
	# Returns { "type": SelectedType, "id": string, "planet": Planet?, "belt": AsteroidBelt?, "station": SpaceStation?, "ship": Ship? }
	var result: Dictionary = { "type": SelectedType.NONE, "id": "" }
	if _current_system == null:
		return result
	var dist_to_center: float = world_pos.length()
	if dist_to_center <= _star_click_radius():
		result.type = SelectedType.STAR
		result.id = "star"
		return result
	for i in _current_system.asteroid_belts.size():
		var b: AsteroidBelt = _current_system.asteroid_belts[i]
		if dist_to_center >= b.inner_radius - 15.0 and dist_to_center <= b.outer_radius + 15.0:
			result.type = SelectedType.BELT
			result.id = "belt:%d" % i
			result.belt = b
			return result
	for i in _station_nodes.size():
		var node: Node2D = _station_nodes[i]
		if world_pos.distance_to(node.position) <= _station_click_radius():
			result.station = node.get_meta("station", null) as SpaceStation
			if result.station != null:
				result.type = SelectedType.STATION
				result.id = "station:%d" % i
			return result
	for i in _ship_nodes.size():
		var node: Node2D = _ship_nodes[i]
		if world_pos.distance_to(node.global_position) <= _ship_click_radius():
			result.ship = node.get_meta("ship", null) as Ship
			if result.ship != null:
				result.type = SelectedType.SHIP
				result.id = "ship:%d" % i
			return result
	for i in _planet_nodes.size():
		var node: Node2D = _planet_nodes[i]
		if world_pos.distance_to(node.position) <= _planet_click_radius() and i < _current_system.planets.size():
			result.type = SelectedType.PLANET
			result.planet = _current_system.planets[i]
			result.id = "planet:%d" % i
			return result
	return result


func _get_tooltip_for_hover(hover: Dictionary) -> PackedStringArray:
	var title: String = ""
	var body: String = ""
	if hover.type == SelectedType.STAR and _current_system != null:
		title = _current_system.name_key + " (Star)"
		var type_name: String = _get_star_type_name(_current_system.star_type)
		body = "Type: %s\n%d planets, %d asteroid belts." % [type_name, _current_system.planets.size(), _current_system.asteroid_belts.size()]
	elif hover.type == SelectedType.PLANET and hover.get("planet", null) != null:
		var p: Planet = hover.planet
		var type_name: String = Planet.PlanetType.keys()[p.type] if p.type >= 0 else "?"
		title = p.name_key
		body = "Type: %s\nSize: %d  Habitability: %.0f%%  Orbit: %.0f" % [type_name, p.size, p.habitability * 100.0, p.orbit_radius]
	elif hover.type == SelectedType.BELT and hover.get("belt", null) != null:
		var b: AsteroidBelt = hover.belt
		title = b.name_key
		body = "Asteroid belt\nInner: %.0f  Outer: %.0f  Asteroids: %d" % [b.inner_radius, b.outer_radius, b.significant_asteroids]
	elif hover.type == SelectedType.STATION and hover.get("station", null) != null:
		var st: SpaceStation = hover.station
		title = st.name_key
		body = "Space station\nBuild queue: %d  Ships in system: %d" % [st.ship_build_queue.size(), _get_ships_in_system_count(st.system_id)]
	elif hover.type == SelectedType.SHIP and hover.get("ship", null) != null:
		var ship: Ship = hover.ship
		title = ship.name_key
		body = "Design: %s\nSystem ID: %d" % [ship.design_id, ship.system_id]
	return PackedStringArray([title, body])


func _on_resource_row_entered(res_type: int) -> void:
	_resource_hover_type = res_type


func _on_resource_row_exited() -> void:
	_resource_hover_type = -1


func _update_hover_tooltip(delta: float) -> void:
	if _hover_tooltip == null or overlay_layer == null:
		return
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	# Resource strip has priority: if mouse is over a resource row, show resource tooltip
	if _resource_hover_type >= 0:
		var name_str: String = GameResources.RESOURCE_NAMES.get(_resource_hover_type, "?")
		var desc: String = GameResources.RESOURCE_DESCRIPTIONS.get(_resource_hover_type, "")
		if _hover_tooltip.has_method("show_tooltip"):
			_hover_tooltip.show_tooltip(name_str, desc, screen_pos)
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var hover: Dictionary = _get_hover_at(world_pos)
	if hover.type == SelectedType.NONE or hover.id.is_empty():
		_hover_accumulator = 0.0
		_hover_last_id = ""
		if _hover_tooltip.has_method("hide_tooltip"):
			_hover_tooltip.hide_tooltip()
		return
	if hover.id != _hover_last_id:
		_hover_accumulator = 0.0
		_hover_last_id = hover.id
	_hover_accumulator += delta
	if _hover_accumulator < 0.35:
		return
	var tt: PackedStringArray = _get_tooltip_for_hover(hover)
	if tt.size() >= 2 and _hover_tooltip.has_method("show_tooltip"):
		_hover_tooltip.show_tooltip(tt[0], tt[1], screen_pos)


func _process(delta: float) -> void:
	if GameState.game_phase != GameState.GamePhase.PLAYING:
		return
	_resource_strip_controller.update_resource_display()
	_update_hover_tooltip(delta)
	if GameState.is_paused():
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
	if _current_system != null and _ship_nodes.size() > 0:
		_update_ship_node_positions()


func _build_system(sys: StarSystem) -> void:
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null

	# Star at center (pass type for black hole / pulsar / neutron drawing)
	var star_color: Color = _star_color(sys.star_type)
	star_node.set_meta("color", star_color)
	star_node.set_meta("star_type", sys.star_type)
	star_node.set_meta("radius", _star_radius())
	star_node.set_meta("star_deposits", sys.star_deposits)
	star_node.set_meta("is_being_collected", player_emp != null and player_emp.get_resource_station_at_body(sys.id, "star", 0) != null)
	star_node.queue_redraw()

	# Asteroid belts (draw first, behind orbits)
	for i in range(sys.asteroid_belts.size()):
		_draw_belt(sys.asteroid_belts[i], i, sys.id, player_emp)

	# Orbits and planets
	_planet_nodes.clear()
	for i in range(sys.planets.size()):
		_draw_orbit(sys.planets[i].orbit_radius)
		_add_planet_node(sys.planets[i], i, sys.id, player_emp)
	# Space stations (player only, at colony orbits)
	_station_nodes.clear()
	for c in stations_node.get_children():
		c.queue_free()
	if EmpireManager != null and player_emp != null:
			# Ensure a station exists for every colony that has orbital_station building
			for col in player_emp.colonies:
				if col.system_id != sys.id or col.planet_index < 0 or col.planet_index >= sys.planets.size():
					continue
				if col.orbital_buildings.has("orbital_station"):
					var planet: Planet = sys.planets[col.planet_index]
					var name_key: String = planet.name_key + " Station"
					player_emp.ensure_station_at_colony(sys.id, col.planet_index, name_key)
			for st in player_emp.get_stations_in_system(sys.id):
				_add_station_node(st as SpaceStation, sys)
			for rs in player_emp.get_resource_stations_in_system(sys.id):
				_add_resource_station_node(rs, sys)
	_refresh_ships_in_system(sys)
	_ensure_overlay_draw()
	_rebuild_jump_targets(sys)


func _ensure_overlay_draw() -> void:
	if _overlay_draw != null and is_instance_valid(_overlay_draw):
		return
	var n := Node2D.new()
	n.name = "JumpPointDecorations"
	n.z_index = -6
	n.set_script(preload("res://scenes/galaxy/system_view_overlay_draw.gd"))
	_overlay_draw = n
	system_content.add_child(n)
	n.set("solar_view", self)


func _rebuild_jump_targets(sys: StarSystem) -> void:
	_jump_targets.clear()
	if sys == null or GalaxyManager == null:
		return
	for nb in GalaxyManager.get_system_neighbors(sys.id):
		_jump_targets.append({
			"id": nb.id,
			"name": nb.name_key,
			"pos": GalaxyManager.get_hyperlane_exit_position_in_system(sys.id, nb.id),
		})


func _jump_neighbor_id_at(world_pos: Vector2) -> int:
	for j in _jump_targets:
		var p: Vector2 = j.get("pos", Vector2.ZERO) as Vector2
		if world_pos.distance_to(p) <= JUMP_RIGHT_CLICK_RADIUS:
			return int(j.get("id", -1))
	return -1


func _refresh_station_nodes() -> void:
	if _current_system == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	_station_nodes.clear()
	for c in stations_node.get_children():
		c.queue_free()
	for col in player_emp.colonies:
		if col.system_id != _current_system.id or col.planet_index < 0 or col.planet_index >= _current_system.planets.size():
			continue
		if col.orbital_buildings.has("orbital_station"):
			var planet: Planet = _current_system.planets[col.planet_index]
			var name_key: String = planet.name_key + " Station"
			player_emp.ensure_station_at_colony(_current_system.id, col.planet_index, name_key)
	for st in player_emp.get_stations_in_system(_current_system.id):
		_add_station_node(st as SpaceStation, _current_system)
	for rs in player_emp.get_resource_stations_in_system(_current_system.id):
		_add_resource_station_node(rs, _current_system)


func _refresh_body_collected_meta() -> void:
	if _current_system == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	star_node.set_meta("is_being_collected", player_emp.get_resource_station_at_body(_current_system.id, "star", 0) != null)
	star_node.queue_redraw()
	for i in _planet_nodes.size():
		var node: Node2D = _planet_nodes[i]
		node.set_meta("is_being_collected", player_emp.get_resource_station_at_body(_current_system.id, "planet", i) != null)
		node.queue_redraw()
	for child in belts_node.get_children():
		var idx: int = child.get_meta("body_index", -1)
		if idx >= 0:
			child.set_meta("is_being_collected", player_emp.get_resource_station_at_body(_current_system.id, "belt", idx) != null)
			child.queue_redraw()


func _refresh_ships_in_system(sys: StarSystem) -> void:
	for c in ships_node.get_children():
		c.queue_free()
	_ship_nodes.clear()
	if sys == null or EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	for s in player_emp.ships:
		var ship: Ship = s as Ship
		if ship == null or ship.empire_id != player_emp.id:
			continue
		# Incoming hyperlane: show at entry jump toward origin system.
		if ship.in_hyperlane and ship.hyperlane_to_system_id == sys.id:
			var pos_in: Vector2 = GalaxyManager.get_hyperlane_exit_position_in_system(sys.id, ship.system_id)
			var node_in := Area2D.new()
			node_in.position = pos_in
			node_in.rotation = ship.facing_angle
			node_in.set_script(preload("res://scenes/galaxy/ship_draw.gd"))
			node_in.set_meta("ship", ship)
			node_in.set_meta("is_incoming_transit", true)
			ships_node.add_child(node_in)
			_ship_nodes.append(node_in)
			continue
		if ship.system_id != sys.id or ship.in_hyperlane:
			continue
		var pos: Vector2 = ship.position_in_system
		var node := Area2D.new()
		node.position = pos
		node.rotation = ship.facing_angle
		node.set_script(preload("res://scenes/galaxy/ship_draw.gd"))
		node.set_meta("ship", ship)
		ships_node.add_child(node)
		_ship_nodes.append(node)
	_update_ship_selection_indicators()


func _on_ship_built(system_id: int) -> void:
	if _current_system != null and _current_system.id == system_id:
		_refresh_ships_in_system(_current_system)


func _on_resource_station_built(system_id: int) -> void:
	if _current_system != null and _current_system.id == system_id:
		_refresh_station_nodes()
		_refresh_body_collected_meta()


func _update_ship_node_positions() -> void:
	if _current_system == null:
		return
	for node in _ship_nodes:
		var ship: Ship = node.get_meta("ship", null) as Ship
		if ship == null:
			continue
		if node.get_meta("is_incoming_transit", false):
			node.position = GalaxyManager.get_hyperlane_exit_position_in_system(_current_system.id, ship.system_id)
		else:
			node.position = ship.position_in_system
		node.rotation = ship.facing_angle


const SHIP_FORMATION_SPACING: float = 14.0

func _assign_ship_targets_in_formation(click_pos: Vector2) -> void:
	var cmd: Array[Ship] = _command_ships_in_current_system()
	var n: int = cmd.size()
	if n <= 0:
		return
	if n == 1:
		cmd[0].target_position = click_pos
		return
	# Line formation: perpendicular to direction from origin to click, centered on click
	var dir: Vector2 = click_pos.normalized() if click_pos.length_squared() > 0.01 else Vector2(1, 0)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	for i in n:
		var ship: Ship = cmd[i]
		var offset: float = (float(i) - (n - 1) * 0.5) * SHIP_FORMATION_SPACING
		ship.target_position = click_pos + perp * offset


func _draw_belt(belt: AsteroidBelt, belt_index: int, system_id: int, player_emp: Empire) -> void:
	var drawer := Node2D.new()
	drawer.set_script(preload("res://scenes/galaxy/belt_draw.gd"))
	drawer.set_meta("inner_radius", belt.inner_radius)
	drawer.set_meta("outer_radius", belt.outer_radius)
	drawer.set_meta("belt", belt)
	drawer.set_meta("body_index", belt_index)
	drawer.set_meta("is_being_collected", player_emp != null and player_emp.get_resource_station_at_body(system_id, "belt", belt_index) != null)
	belts_node.add_child(drawer)


func _draw_orbit(radius: float) -> void:
	var orbit_drawer := Node2D.new()
	orbit_drawer.set_script(preload("res://scenes/galaxy/orbit_draw.gd"))
	orbit_drawer.set_meta("radius", radius)
	orbits_node.add_child(orbit_drawer)


func _add_planet_node(planet: Planet, planet_index: int, system_id: int, player_emp: Empire) -> void:
	var pos := Vector2(cos(planet.orbit_angle), sin(planet.orbit_angle)) * planet.orbit_radius
	var node := Node2D.new()
	node.position = pos
	node.set_script(preload("res://scenes/galaxy/planet_draw.gd"))
	node.set_meta("planet", planet)
	node.set_meta("color", _planet_color(planet.type))
	node.set_meta("is_being_collected", player_emp != null and player_emp.get_resource_station_at_body(system_id, "planet", planet_index) != null)
	planets_node.add_child(node)
	_planet_nodes.append(node)


func _add_station_node(station: SpaceStation, sys: StarSystem) -> void:
	if station.planet_index < 0 or station.planet_index >= sys.planets.size():
		return
	var planet: Planet = sys.planets[station.planet_index]
	var pos := Vector2(cos(planet.orbit_angle), sin(planet.orbit_angle)) * planet.orbit_radius
	# Offset slightly so station doesn't sit exactly on planet
	pos += pos.normalized() * 12.0
	var node := Node2D.new()
	node.position = pos
	node.set_script(preload("res://scenes/galaxy/station_draw.gd"))
	node.set_meta("station", station)
	stations_node.add_child(node)
	_station_nodes.append(node)


func _get_resource_station_position(rs, sys: StarSystem) -> Vector2:
	if rs.body_type == "star":
		return Vector2(12.0, 0.0)
	if rs.body_type == "planet" and rs.body_index >= 0 and rs.body_index < sys.planets.size():
		var planet: Planet = sys.planets[rs.body_index]
		var pos: Vector2 = Vector2(cos(planet.orbit_angle), sin(planet.orbit_angle)) * planet.orbit_radius
		pos += pos.normalized() * 12.0
		return pos
	if rs.body_type == "belt" and rs.body_index >= 0 and rs.body_index < sys.asteroid_belts.size():
		var belt: AsteroidBelt = sys.asteroid_belts[rs.body_index]
		var mid_r: float = (belt.inner_radius + belt.outer_radius) * 0.5
		return Vector2(mid_r, 0.0)
	return Vector2.ZERO


func _add_resource_station_node(rs, sys: StarSystem) -> void:
	var pos: Vector2 = _get_resource_station_position(rs, sys)
	var node := Node2D.new()
	node.position = pos
	node.set_script(preload("res://scenes/galaxy/station_draw.gd"))
	node.set_meta("station", rs)
	stations_node.add_child(node)
	_station_nodes.append(node)


func _get_deposits_for_body(sys: StarSystem, body_type: String, body_index: int) -> Array:
	if sys == null:
		return []
	if body_type == "star":
		return sys.star_deposits
	if body_type == "planet" and body_index >= 0 and body_index < sys.planets.size():
		return sys.planets[body_index].deposits
	if body_type == "belt" and body_index >= 0 and body_index < sys.asteroid_belts.size():
		return sys.asteroid_belts[body_index].deposits
	return []


func _format_deposits_line(deposits: Array) -> String:
	if deposits.is_empty():
		return ""
	var parts: PackedStringArray = []
	for d in deposits:
		var rt: int = d.get("resource_type", 0)
		var amt: float = d.get("amount", 0.0)
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		parts.append("%s %.0f" % [short, amt])
	return "  ".join(parts)


func _get_build_resource_station_hint(body_type: String, body_index: int) -> String:
	if _current_system == null or EmpireManager == null:
		return ""
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return ""
	var has_construction: bool = false
	for ship in _command_ships_in_current_system():
		if ship.design_id == "construction_ship":
			has_construction = true
			break
	if not has_construction:
		return ""
	var deposits: Array = _get_deposits_for_body(_current_system, body_type, body_index)
	if deposits.is_empty():
		return ""
	if player_emp.get_resource_station_at_body(_current_system.id, body_type, body_index) != null:
		return ""
	if not player_emp.resources.can_afford(_ResourceStationScript.get_build_cost()):
		return "\n\nRight-click to build resource station (need more resources)."
	return "\n\nRight-click to build resource station."


func _parse_hover_body(hover: Dictionary) -> Dictionary:
	var out: Dictionary = { "body_type": "", "body_index": 0 }
	var id_str: String = hover.get("id", "")
	if id_str == "star":
		out.body_type = "star"
		out.body_index = 0
		return out
	if id_str.begins_with("planet:"):
		out.body_type = "planet"
		out.body_index = int(id_str.get_slice(":", 1))
		return out
	if id_str.begins_with("belt:"):
		out.body_type = "belt"
		out.body_index = int(id_str.get_slice(":", 1))
		return out
	return out


func _try_build_resource_station(hover: Dictionary, _world_pos: Vector2) -> bool:
	if _current_system == null or EmpireManager == null:
		return false
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return false
	var ht: int = hover.get("type", -1)
	if ht != SelectedType.STAR and ht != SelectedType.PLANET and ht != SelectedType.BELT:
		return false
	var body: Dictionary = _parse_hover_body(hover)
	var deposits: Array = _get_deposits_for_body(_current_system, body.body_type, body.body_index)
	if deposits.is_empty():
		return false
	var construction_ship: Ship = null
	for s in _command_ships_in_current_system():
		if s.design_id == "construction_ship":
			construction_ship = s
			break
	if construction_ship == null:
		return false
	if player_emp.get_resource_station_at_body(_current_system.id, body.body_type, body.body_index) != null:
		return false
	var cost: Dictionary = _ResourceStationScript.get_build_cost()
	if not player_emp.resources.can_afford(cost):
		return false
	player_emp.resources.pay(cost)
	construction_ship.build_order = {
		"type": "resource_station",
		"system_id": _current_system.id,
		"body_type": body.body_type,
		"body_index": body.body_index,
		"progress_months": 0,
		"build_time_months": _ResourceStationScript.BUILD_TIME_MONTHS
	}
	if construction_ship.system_id == _current_system.id:
		construction_ship.target_system_id = -1
		construction_ship.target_position = construction_ship.get_build_target_position_in_system(_current_system, body.body_type, body.body_index)
	else:
		construction_ship.target_system_id = _current_system.id
		construction_ship.target_position = Vector2(-99999.0, -99999.0)
		if GalaxyManager != null:
			var path: Array = GalaxyManager.get_path_between_systems(construction_ship.system_id, _current_system.id)
			construction_ship.path_queue.clear()
			for i in range(1, path.size()):
				construction_ship.path_queue.append(path[i])
			if path.size() >= 2:
				construction_ship.target_system_id = path[1]
	_refresh_ships_in_system(_current_system)
	return true


func _get_build_mining_station_menu_item(hover: Dictionary) -> Dictionary:
	# Returns { "show": bool, "enabled": bool, "label": String }
	var out: Dictionary = { "show": false, "enabled": false, "label": "Build mining station" }
	var ht: int = hover.get("type", -1)
	if ht != SelectedType.STAR and ht != SelectedType.PLANET and ht != SelectedType.BELT:
		return out
	if _current_system == null or EmpireManager == null:
		return out
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return out
	out.show = true
	var body: Dictionary = _parse_hover_body(hover)
	var deposits: Array = _get_deposits_for_body(_current_system, body.body_type, body.body_index)
	if deposits.is_empty():
		out.label = "Build mining station (No resource deposits here)"
		return out
	var has_construction: bool = false
	for ship in _command_ships_in_current_system():
		if ship.design_id == "construction_ship":
			has_construction = true
			break
	if not has_construction:
		out.label = "Build mining station (Select a construction ship first)"
		return out
	if player_emp.get_resource_station_at_body(_current_system.id, body.body_type, body.body_index) != null:
		out.label = "Build mining station (Station already built)"
		return out
	var cost: Dictionary = _ResourceStationScript.get_build_cost()
	if not player_emp.resources.can_afford(cost):
		out.label = "Build mining station (Insufficient resources)"
		return out
	out.enabled = true
	out.label = "Build mining station"
	return out


func _can_colonize_at_hover(hover: Dictionary) -> bool:
	if hover.get("type", -1) != SelectedType.PLANET or _current_system == null or EmpireManager == null:
		return false
	var planet: Planet = hover.get("planet", null) as Planet
	if planet == null:
		return false
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return false
	if planet.habitability <= 0.0 or player_emp.get_colony(_current_system.id, _current_system.planets.find(planet)) != null:
		return false
	for s in _command_ships_in_current_system():
		if s.design_id == "colony_ship":
			return true
	return false


func _show_right_click_context_menu(screen_pos: Vector2, world_pos: Vector2, hover: Dictionary) -> void:
	_pending_world_pos = world_pos
	_pending_hover = hover
	_context_menu.clear()
	var build_item: Dictionary = _get_build_mining_station_menu_item(hover)
	if build_item.show:
		_context_menu.add_item(build_item.label, _MENU_ID_BUILD_MINING_STATION)
		_context_menu.set_item_disabled(_context_menu.item_count - 1, not build_item.enabled)
	if _command_ships_in_current_system().size() > 0:
		_context_menu.add_item("Move here", _MENU_ID_MOVE_HERE)
	if _can_colonize_at_hover(hover):
		_context_menu.add_item("Colonize", _MENU_ID_COLONIZE)
	if _context_menu.item_count == 0:
		return
	# Single option: execute directly instead of showing dropdown
	if _context_menu.item_count == 1:
		if not _context_menu.is_item_disabled(0):
			_on_context_menu_id_pressed(_context_menu.get_item_id(0))
		return
	_context_menu.popup(Rect2i(int(screen_pos.x), int(screen_pos.y), 0, 0))


func _on_context_menu_id_pressed(id: int) -> void:
	if id == _MENU_ID_BUILD_MINING_STATION:
		_try_build_resource_station(_pending_hover, _pending_world_pos)
	elif id == _MENU_ID_MOVE_HERE:
		_assign_ship_targets_in_formation(_pending_world_pos)
		_refresh_ships_in_system(_current_system)
	elif id == _MENU_ID_COLONIZE:
		var body: Dictionary = _parse_hover_body(_pending_hover)
		var planet_index: int = body.body_index if body.body_type == "planet" else -1
		if planet_index >= 0 and _current_system != null and planet_index < _current_system.planets.size():
			_colonize_with_ship(planet_index)
	_refresh_ships_in_system(_current_system)
	_update_info_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Pan/zoom/select: use _unhandled_input so UI buttons receive clicks first
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level * _zoom_speed())
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level / _zoom_speed())
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = e.pressed
			if e.pressed:
				_drag_start = e.position
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if not e.pressed:
				var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * e.position
				var jump_nid: int = _jump_neighbor_id_at(world_pos)
				if jump_nid >= 0 and ShipMoveOrder != null and _current_system != null:
					var cmd_jump: Array[Ship] = _command_ships_in_current_system()
					if cmd_jump.size() > 0:
						ShipMoveOrder.issue_move_orders_for_ships(cmd_jump, _current_system.id, jump_nid)
						_refresh_ships_in_system(_current_system)
						get_viewport().set_input_as_handled()
						return
				var hover: Dictionary = _get_hover_at(world_pos)
				var ht: int = hover.get("type", -1)
				var hover_is_body: bool = (ht == SelectedType.STAR or ht == SelectedType.PLANET or ht == SelectedType.BELT)
				if _command_ships_in_current_system().size() > 0 or hover_is_body:
					_show_right_click_context_menu(e.position, world_pos, hover)
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_select_dragging = true
				_select_drag_start = e.position
				_select_drag_end = e.position
				if _selection_rect != null:
					_update_selection_rect()
					_selection_rect.visible = true
			else:
				if _selection_rect != null:
					_selection_rect.visible = false
				if _select_dragging:
					if _select_drag_start.distance_to(e.position) < _click_drag_threshold():
						var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * e.position
						_try_select_at(world_pos)
						_update_ship_selection_indicators()
					else:
						_finish_drag_select(_select_drag_start, e.position)
						_update_ship_selection_indicators()
				_select_dragging = false
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		var e: InputEventMouseMotion = event
		if _panning:
			var delta: Vector2 = (e.position - _drag_start) / _zoom_level
			camera.position -= delta
			_drag_start = e.position
			get_viewport().set_input_as_handled()
		elif _select_dragging:
			_select_drag_end = e.position
			_update_selection_rect()
			get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE and SelectionManager != null:
			SelectionManager.set_selection([])
			_sync_local_ships_from_selection_manager()
			_update_ship_selection_indicators()
			get_viewport().set_input_as_handled()
		elif k.pressed and not k.echo and k.keycode == KEY_G:
			if _government_overlay_container != null and is_instance_valid(_government_overlay_container):
				_on_government_overlay_closed(_government_overlay_container)
			else:
				_open_government_overlay()
			get_viewport().set_input_as_handled()


func _set_zoom(z: float) -> void:
	_zoom_level = clampf(z, _min_zoom(), _max_zoom())
	camera.zoom = Vector2(_zoom_level, _zoom_level)


func _update_selection_rect() -> void:
	if _selection_rect == null:
		return
	var min_p: Vector2 = Vector2(minf(_select_drag_start.x, _select_drag_end.x), minf(_select_drag_start.y, _select_drag_end.y))
	var max_p: Vector2 = Vector2(maxf(_select_drag_start.x, _select_drag_end.x), maxf(_select_drag_start.y, _select_drag_end.y))
	_selection_rect.position = min_p
	_selection_rect.size = max_p - min_p


func _finish_drag_select(from: Vector2, to: Vector2) -> void:
	var min_p: Vector2 = Vector2(minf(from.x, to.x), minf(from.y, to.y))
	var max_p: Vector2 = Vector2(maxf(from.x, to.x), maxf(from.y, to.y))
	var rect: Rect2 = Rect2(min_p, max_p - min_p)
	if rect.size.x < 4.0 and rect.size.y < 4.0:
		return
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	_selected_type = SelectedType.SHIP
	_selected_ships.clear()
	for node in _ship_nodes:
		var ship: Ship = node.get_meta("ship", null) as Ship
		if ship == null:
			continue
		var screen_pos: Vector2 = canvas * node.global_position
		if rect.has_point(screen_pos):
			_selected_ships.append(ship)
	if _selected_ships.is_empty():
		_selected_type = SelectedType.NONE
		if SelectionManager != null:
			SelectionManager.set_selection([])
	else:
		var payload: Array = []
		for sh in _selected_ships:
			payload.append(_ship_to_selection_data(sh as Ship))
		if SelectionManager != null:
			SelectionManager.set_selection(payload)
	_sync_local_ships_from_selection_manager()
	_update_info_panel()


func _try_select_at(world_pos: Vector2) -> void:
	_selected_type = SelectedType.NONE
	_selected_planet = null
	_selected_belt = null
	_selected_station = null
	_selected_ships.clear()

	var dist_to_center: float = world_pos.length()
	# Star (center)
	if dist_to_center <= _star_click_radius():
		_selected_type = SelectedType.STAR
		_update_info_panel()
		return
	# Asteroid belts (ring hit)
	if _current_system != null:
		for b in _current_system.asteroid_belts:
			if dist_to_center >= b.inner_radius - 15.0 and dist_to_center <= b.outer_radius + 15.0:
				_selected_type = SelectedType.BELT
				_selected_belt = b
				_update_info_panel()
				return
	# Space stations and resource stations (check before planets so station is clickable when overlapping)
	for i in _station_nodes.size():
		var node: Node2D = _station_nodes[i]
		if world_pos.distance_to(node.position) <= _station_click_radius():
			_selected_station = node.get_meta("station", null)
			if _selected_station != null:
				_selected_type = SelectedType.STATION
				# Direct-open station management for space stations (not resource stations)
				var body_type_val = _selected_station.get("body_type")
				if (body_type_val == null or body_type_val == "") and EmpireManager != null:
					var player_emp: Empire = EmpireManager.get_player_empire()
					if player_emp != null:
						_open_station_window(_selected_station as SpaceStation, player_emp)
				_update_info_panel()
				return
	# Ships (before planets so ships are clickable)
	for node in _ship_nodes:
		var gp: Vector2 = node.global_position
		if world_pos.distance_to(gp) <= _ship_click_radius():
			var ship: Ship = node.get_meta("ship", null) as Ship
			if ship != null:
				_selected_type = SelectedType.SHIP
				_selected_ships = [ship]
				if SelectionManager != null:
					SelectionManager.set_selection([_ship_to_selection_data(ship)])
				_update_info_panel()
				return
	# Planets
	for i in _planet_nodes.size():
		var node: Node2D = _planet_nodes[i]
		var d: float = world_pos.distance_to(node.position)
		if d <= _planet_click_radius() and i < _current_system.planets.size():
			_selected_type = SelectedType.PLANET
			_selected_planet = _current_system.planets[i]
			# Direct-open colony management when planet has a colony
			if EmpireManager != null:
				var player_emp: Empire = EmpireManager.get_player_empire()
				if player_emp != null and player_emp.get_colony(GameState.selected_system_id, i) != null:
					GameState.selected_colony_system_id = GameState.selected_system_id
					GameState.selected_colony_planet_index = i
					GameState.planet_view_return_scene = _planet_return_scene()
					_open_planet_view_overlay()
			_update_info_panel()
			return
	if SelectionManager != null:
		SelectionManager.set_selection([])
	_sync_local_ships_from_selection_manager()
	_update_info_panel()


func _get_planet_index_at(world_pos: Vector2) -> int:
	if _current_system == null:
		return -1
	for i in _planet_nodes.size():
		var node: Node2D = _planet_nodes[i]
		if world_pos.distance_to(node.position) <= _planet_click_radius() and i < _current_system.planets.size():
			return i
	return -1


func _colonize_with_ship(planet_index: int) -> void:
	if EmpireManager == null or _current_system == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var colony_ship_to_use: Ship = null
	for s in _command_ships_in_current_system():
		if s.design_id == "colony_ship":
			colony_ship_to_use = s
			break
	if colony_ship_to_use == null:
		return
	player_emp.ships.erase(colony_ship_to_use)
	_selected_ships.erase(colony_ship_to_use)
	if SelectionManager != null:
		var keep: Array = []
		for sd in SelectionManager.selected_ships:
			if sd.ship_name != colony_ship_to_use.name_key or sd.galaxy_empire_id != colony_ship_to_use.empire_id:
				keep.append(sd)
		SelectionManager.set_selection(keep)
	var colony := Colony.new(player_emp.id, _current_system.id, planet_index, false)
	player_emp.add_colony(colony)
	_refresh_ships_in_system(_current_system)
	_update_ship_selection_indicators()


func _update_info_panel() -> void:
	manage_colony_button.visible = false
	manage_station_button.visible = false
	if _selected_type == SelectedType.NONE:
		info_title.text = "Select a body"
		info_text.text = "Click the star, a planet, station, or ships. Middle mouse to pan. Drag to select multiple ships. Fleet panel (bottom-left) lists selected ships."
		return
	if _selected_type == SelectedType.SHIP and _selected_ships.size() > 0:
		info_title.text = "Ships"
		info_text.text = "Selection and orders: use the fleet panel (bottom-left). Right-click empty space to move selected ships in formation."
		return
	if _selected_type == SelectedType.STAR and _current_system != null:
		var type_name: String = _get_star_type_name(_current_system.star_type)
		info_title.text = _current_system.name_key + " (Star)"
		info_text.text = "Type: %s\n\n" % type_name
		if _current_system.is_special_star():
			info_text.text += _get_special_star_description(_current_system.star_type)
		else:
			info_text.text += "Main-sequence star. %d planets, %d asteroid belts in system." % [_current_system.planets.size(), _current_system.asteroid_belts.size()]
		var deposit_line: String = _format_deposits_line(_current_system.star_deposits)
		if deposit_line != "":
			info_text.text += "\n\nDeposits: " + deposit_line
		info_text.text += _get_build_resource_station_hint("star", 0)
		return
	if _selected_type == SelectedType.PLANET and _selected_planet != null:
		var p: Planet = _selected_planet
		var type_name: String = Planet.PlanetType.keys()[p.type] if p.type >= 0 else "?"
		info_title.text = p.name_key
		info_text.text = "Type: %s\nSize: %d\nHabitability: %.0f%%\nOrbit radius: %.0f" % [type_name, p.size, p.habitability * 100.0, p.orbit_radius]
		var planet_index: int = -1
		for i in _current_system.planets.size():
			if _current_system.planets[i] == p:
				planet_index = i
				break
		var deposit_line: String = _format_deposits_line(p.deposits)
		if deposit_line != "":
			info_text.text += "\n\nDeposits: " + deposit_line
		info_text.text += _get_build_resource_station_hint("planet", planet_index)
		# Manage Colony removed from info panel — colonised planets open colony screen directly on click
		return
	if _selected_type == SelectedType.STATION and _selected_station != null:
		var body_type_val = _selected_station.get("body_type")
		if body_type_val != null and body_type_val != "":
			var rs = _selected_station
			info_title.text = rs.name_key
			var deposits: Array = _get_deposits_for_body(_current_system, rs.body_type, rs.body_index)
			var deposit_line: String = _format_deposits_line(deposits)
			info_text.text = "Resource station\nCollects from stellar body.\n\nDeposits: " + (deposit_line if deposit_line != "" else "—")
		else:
			var st: SpaceStation = _selected_station as SpaceStation
			info_title.text = st.name_key
			info_text.text = "Space station\nShip build queue: %d\nShips in system: %d" % [st.ship_build_queue.size(), _get_ships_in_system_count(st.system_id)]
		# Manage Station removed from info panel — station opens management screen directly on click
		return
	if _selected_type == SelectedType.BELT and _selected_belt != null:
		var b: AsteroidBelt = _selected_belt
		info_title.text = b.name_key
		info_text.text = "Asteroid belt\nInner radius: %.0f\nOuter radius: %.0f\nSignificant asteroids: %d" % [b.inner_radius, b.outer_radius, b.significant_asteroids]
		var belt_index: int = _current_system.asteroid_belts.find(b)
		var deposit_line: String = _format_deposits_line(b.deposits)
		if deposit_line != "":
			info_text.text += "\n\nDeposits: " + deposit_line
		info_text.text += _get_build_resource_station_hint("belt", belt_index)
		return


func _update_ship_selection_indicators() -> void:
	for node in _ship_nodes:
		var ship: Ship = node.get_meta("ship", null) as Ship
		if ship == null:
			continue
		var selected: bool = false
		if SelectionManager != null:
			for sd in SelectionManager.selected_ships:
				if sd.matches_ship(ship):
					selected = true
					break
		if "selected" in node:
			node.selected = selected
		node.queue_redraw()
		node.modulate = Color(1.2, 1.2, 0.6) if selected else Color.WHITE
	_update_ships_selected_label()


func _update_ships_selected_label() -> void:
	if _ships_selected_label == null:
		return
	if _selected_ships.size() > 0:
		_ships_selected_label.visible = true
		_ships_selected_label.text = " %d ship(s) selected — Right-click to move "
	else:
		_ships_selected_label.visible = false


func _get_ships_in_system_count(system_id: int) -> int:
	if EmpireManager == null:
		return 0
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return 0
	var n: int = 0
	for s in player_emp.ships:
		if (s as Ship).system_id == system_id:
			n += 1
	return n


func _get_star_type_name(star_type: StarSystem.StarType) -> String:
	if star_type == StarSystem.StarType.BLACK_HOLE:
		return "Black Hole"
	if star_type == StarSystem.StarType.PULSAR:
		return "Pulsar"
	if star_type == StarSystem.StarType.NEUTRON_STAR:
		return "Neutron Star"
	var names: PackedStringArray = StarSystem.StarType.keys()
	if int(star_type) < names.size():
		return "Type %s Star" % names[star_type]
	return "Star"


func _get_special_star_description(star_type: StarSystem.StarType) -> String:
	if star_type == StarSystem.StarType.BLACK_HOLE:
		return "A black hole. Few or no stable orbits; asteroid belts and planets are rare."
	if star_type == StarSystem.StarType.PULSAR:
		return "A pulsar—rapidly rotating neutron star with intense radiation. Hostile to most life."
	if star_type == StarSystem.StarType.NEUTRON_STAR:
		return "A neutron star. Extremely dense remnant; few planets can exist in this system."
	return ""


func _on_planets_pressed() -> void:
	_open_colonies_overlay()


func _on_technology_pressed() -> void:
	_open_technology_overlay()


func _on_tech_tree_pressed() -> void:
	_open_tech_tree_overlay()


func _on_leaders_pressed() -> void:
	_open_leaders_overlay()


func _on_government_pressed() -> void:
	_open_government_overlay()


func _open_colonies_overlay() -> void:
	var colonies: Control = _instantiate_overlay(overlay_colonies, ProjectPaths.SCENE_COLONIES_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), colonies, _overlay_rect("colonies"), false, false)
	colonies.set_manage_callback(func(sid: int, pidx: int) -> void:
		GameState.selected_colony_system_id = sid
		GameState.selected_colony_planet_index = pidx
		GameState.planet_view_return_scene = _planet_return_scene()
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


func _open_leaders_overlay() -> void:
	var leaders: Control = _instantiate_overlay(overlay_leaders, ProjectPaths.SCENE_LEADERS_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), leaders, _overlay_rect("leaders"), false, false)
	var player_emp: Empire = EmpireManager.get_player_empire() if EmpireManager != null else null
	if player_emp != null and leaders.has_method("setup"):
		leaders.setup(player_emp)
	if leaders.has_signal("closed"):
		leaders.closed.connect(_on_generic_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _open_government_overlay() -> void:
	var gov: Control = _instantiate_overlay(overlay_government, ProjectPaths.SCENE_GOVERNMENT_OVERLAY) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), gov, Vector4.ZERO, true, false)
	_government_overlay_container = container
	if gov.has_signal("closed"):
		gov.closed.connect(_on_government_overlay_closed.bind(container))
	overlay_layer.add_child(container)


func _on_government_overlay_closed(container: Control) -> void:
	_government_overlay_container = null
	if is_instance_valid(container):
		container.queue_free()
	_resource_strip_controller.update_resource_display()


func _on_generic_overlay_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_resource_strip_controller.update_resource_display()


func _on_tech_tree_overlay_closed(overlay_container: Control, prev_speed: int) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	GameState.set_game_speed(prev_speed)
	_resource_strip_controller.update_resource_display()


func _open_planet_view_overlay() -> void:
	var pv: Control = _instantiate_overlay(overlay_planet_view, ProjectPaths.SCENE_PLANET_VIEW) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), pv, _overlay_rect("planet_view"), false, false)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pv.has_signal("closed"):
		pv.closed.connect(_on_planet_view_overlay_closed.bind(container))
	if pv.has_signal("colony_updated"):
		pv.colony_updated.connect(_on_planet_view_colony_updated)
	overlay_layer.add_child(container)


func _on_planet_view_colony_updated() -> void:
	_refresh_station_nodes()


func _on_planet_view_overlay_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
	_resource_strip_controller.update_resource_display()


func _max_orbit_radius_for_boundary(sys: StarSystem) -> float:
	var m := 200.0
	for p in sys.planets:
		m = maxf(m, p.orbit_radius)
	for b in sys.asteroid_belts:
		m = maxf(m, b.outer_radius)
	return maxf(m * 1.15, GalaxyManager.SYSTEM_EDGE_RADIUS)


func _next_hop_system_id_for_path(ship: Ship) -> int:
	if ship == null or _current_system == null:
		return -1
	if ship.in_hyperlane and ship.hyperlane_to_system_id == _current_system.id:
		return -2
	if ship.target_system_id >= 0:
		return ship.target_system_id
	return -1


func _is_ship_selected_for_overlay(ship: Ship) -> bool:
	if ship == null or SelectionManager == null:
		return false
	for sd in SelectionManager.selected_ships:
		if sd is ShipData and (sd as ShipData).matches_ship(ship):
			return true
	return false


func _draw_dashed_line_on(canvas: CanvasItem, from_p: Vector2, to_p: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var v: Vector2 = to_p - from_p
	var L: float = v.length()
	if L < 0.5:
		return
	var u: Vector2 = v / L
	var t: float = 0.0
	while t < L:
		var te: float = minf(t + dash, L)
		canvas.draw_line(from_p + u * t, from_p + u * te, col, width)
		t = te + gap


func _draw_arrow_at_end(canvas: CanvasItem, from_p: Vector2, to_p: Vector2, col: Color, head_len: float) -> void:
	var d: Vector2 = to_p - from_p
	if d.length_squared() < 4.0:
		return
	var dir: Vector2 = d.normalized()
	var tip: Vector2 = to_p
	var base: Vector2 = tip - dir * head_len
	var perp: Vector2 = Vector2(-dir.y, dir.x) * head_len * 0.45
	var pts: PackedVector2Array = PackedVector2Array([tip, base + perp, base - perp])
	var cols: PackedColorArray = PackedColorArray([col, col, col])
	canvas.draw_polygon(pts, cols)


## Called from system_view_overlay_draw.gd each frame.
func _draw_system_view_overlay(canvas: CanvasItem) -> void:
	# AUDIT: NEEDS REVIEW — if camera zoom/parallax decouple label readability from _draw scale, use Control labels.
	if _current_system == null:
		return
	var sys: StarSystem = _current_system
	var boundary_r: float = _max_orbit_radius_for_boundary(sys)
	var line_col := Color(0.35, 0.55, 0.78, 0.55)
	var jump_ring := Color(0.28, 0.68, 0.98, 0.8)
	var jump_fill := Color(0.12, 0.32, 0.52, 0.4)
	var font: Font = ThemeDB.fallback_font
	var seg_count: int = 96
	for i in seg_count:
		if i % 2 != 0:
			continue
		var a0: float = TAU * float(i) / float(seg_count)
		var a1: float = TAU * float(i + 1) / float(seg_count)
		canvas.draw_arc(Vector2.ZERO, boundary_r, a0, a1, 6, line_col, 2.0, true)
	for j in _jump_targets:
		var jp: Vector2 = j.get("pos", Vector2.ZERO) as Vector2
		var nb_name: String = str(j.get("name", "?"))
		canvas.draw_circle(jp, JUMP_MARKER_RADIUS, jump_fill)
		canvas.draw_arc(jp, JUMP_MARKER_RADIUS, 0.0, TAU, 28, jump_ring, 2.5, true)
		canvas.draw_string(font, jp + Vector2(-36.0, -JUMP_MARKER_RADIUS - 8.0), nb_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 0.9, 1.0, 0.95))
	var path_col := Color(0.95, 0.72, 0.22, 0.92)
	var path_w: float = 2.5
	for node in _ship_nodes:
		var ship: Ship = node.get_meta("ship", null) as Ship
		if ship == null or not _is_ship_selected_for_overlay(ship):
			continue
		var next_id: int = _next_hop_system_id_for_path(ship)
		var from_v: Vector2 = node.position
		if next_id == -2:
			_draw_dashed_line_on(canvas, from_v, Vector2.ZERO, path_col, path_w, 14.0, 10.0)
			_draw_arrow_at_end(canvas, from_v, Vector2.ZERO, path_col, 18.0)
		elif next_id >= 0:
			var jpt: Vector2 = GalaxyManager.get_hyperlane_exit_position_in_system(sys.id, next_id)
			_draw_dashed_line_on(canvas, from_v, jpt, path_col, path_w, 14.0, 10.0)
			_draw_arrow_at_end(canvas, from_v, jpt, path_col, 18.0)


func _on_back_pressed() -> void:
	if embedded_in_game_scene:
		var host: Node = get_parent()
		if host != null and host.has_method("close_embedded_solar_system"):
			host.call("close_embedded_solar_system")
		return
	get_tree().change_scene_to_file(ProjectPaths.SCENE_GAME_SCENE)


func _on_manage_colony_pressed() -> void:
	var planet_index: Variant = manage_colony_button.get_meta("planet_index", -1)
	if planet_index is int and planet_index >= 0:
		GameState.selected_colony_system_id = GameState.selected_system_id
		GameState.selected_colony_planet_index = planet_index
		GameState.planet_view_return_scene = _planet_return_scene()
		_open_planet_view_overlay()


func _on_manage_station_pressed() -> void:
	if _selected_station == null or EmpireManager == null:
		return
	var body_type_val = _selected_station.get("body_type")
	if body_type_val != null and body_type_val != "":
		return  # Resource station has no manage window
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	_open_station_window(_selected_station as SpaceStation, player_emp)


func _open_station_window(station: SpaceStation, empire: Empire) -> void:
	var win: Control = _instantiate_overlay(overlay_space_station, ProjectPaths.SCENE_SPACE_STATION_WINDOW) as Control
	var container: Control = OverlayManager.create_overlay_container(_overlay_dimmer_color(), win, _overlay_rect("station"), false, false)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if win.has_method("setup"):
		win.setup(station, empire)
	if win.has_signal("closed"):
		win.closed.connect(_on_station_window_closed.bind(container))
	overlay_layer.add_child(container)


func _on_station_window_closed(overlay_container: Control) -> void:
	if is_instance_valid(overlay_container):
		overlay_container.queue_free()
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
		designer.closed.connect(_on_generic_overlay_closed.bind(container))
