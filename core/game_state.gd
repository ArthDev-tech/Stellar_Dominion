extends Node
## Global game state: selected empire/system/ship, pause/speed, game phase.
## Access via autoload: GameState

enum GamePhase { MAIN_MENU, PLAYING, PAUSED }

## Time scale options: 0 = paused, 1..size = index into available_scales.
var available_scales: Array = [0.1, 0.25, 0.5, 1.0, 2.0, 3.0]

var game_phase: GamePhase = GamePhase.MAIN_MENU
var game_speed: int = 4  ## 0 = paused, 1..available_scales.size() = scale index (4 = 1.0)
var game_date_months: int = 0
var day_of_month: int = 0  ## 0–29; when 30 we advance month
var _sub_day_accumulator: float = 0.0  ## Fractional days before next calendar day (smooth ship movement)
var selected_system_id: int = -1  ## StarSystem id, -1 if none
var selected_ship_id: int = -1
var selected_empire_id: int = 0  ## Player empire id; 0 = player
var player_empire_id: int = 0
var selected_colony_system_id: int = -1
var selected_colony_planet_index: int = -1
var planet_view_return_scene: String = "res://scenes/galaxy/game_scene.tscn"  ## Override with ProjectPaths.SCENE_GAME_SCENE or SCENE_SOLAR_SYSTEM_VIEW when opening planet view

signal system_selected(system_id: int)
signal empire_changed(empire_id: int)
signal game_speed_changed(speed: int)


func _ready() -> void:
	if not InputMap.has_action("game_pause"):
		InputMap.add_action("game_pause")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event("game_pause", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func set_selected_system(system_id: int) -> void:
	if selected_system_id == system_id:
		return
	selected_system_id = system_id
	system_selected.emit(system_id)


func set_selected_empire(empire_id: int) -> void:
	if selected_empire_id == empire_id:
		return
	selected_empire_id = empire_id
	empire_changed.emit(empire_id)


func get_time_scale_multiplier() -> float:
	if game_speed <= 0 or game_speed > available_scales.size():
		return 0.0
	return available_scales[game_speed - 1] as float


func set_time_scale(scale: float) -> void:
	for i in available_scales.size():
		if is_equal_approx(available_scales[i] as float, scale):
			set_game_speed(i + 1)
			return
	# Fallback: nearest or 1x
	set_game_speed(4)


func set_game_speed(speed: int) -> void:
	game_speed = clampi(speed, 0, available_scales.size())
	if EventBus != null:
		EventBus.pause_state_changed.emit(game_speed == 0)
	game_speed_changed.emit(game_speed)


func toggle_pause() -> void:
	if game_phase != GamePhase.PLAYING:
		return
	if game_speed == 0:
		set_game_speed(4)
	else:
		set_game_speed(0)


func is_paused() -> bool:
	return game_speed == 0


func start_new_game() -> void:
	game_phase = GamePhase.PLAYING
	game_speed = 0
	game_date_months = 0
	day_of_month = 0
	_sub_day_accumulator = 0.0
	selected_system_id = -1
	selected_ship_id = -1
	selected_empire_id = player_empire_id
	if SelectionManager != null:
		SelectionManager.clear_selection()
		SelectionManager.clear_icon_registry()


## Advance game time by delta_days (can be fractional for smooth ship movement at low speed).
## Ship movement is applied every call; calendar day/month advance only when accumulated days >= 1.
func advance_day(delta_days: float = 1.0) -> void:
	if delta_days <= 0.0:
		return
	if EconomyManager != null:
		EconomyManager.process_ship_movement(delta_days)
	_sub_day_accumulator += delta_days
	while _sub_day_accumulator >= 1.0:
		_sub_day_accumulator -= 1.0
		day_of_month += 1
		if day_of_month >= 30:
			day_of_month = 0
			advance_month()


func advance_month() -> void:
	game_date_months += 1
	if EconomyManager != null:
		EconomyManager.process_month()
