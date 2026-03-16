extends DraggableOverlay
## Lists player colonies; "Manage" opens planet view overlay.
## Emits closed when Close is pressed.

signal closed

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Margin/VBox/TitleBar/CloseButton
@onready var list_container: VBoxContainer = $Margin/VBox/ScrollContainer/ListContainer

var _player_empire: Empire
var _on_manage_requested: Callable  ## (system_id: int, planet_index: int) -> void


func _ready() -> void:
	super._ready()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a0f1c")
	style.border_color = Color("#1e3a5f")
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	add_theme_stylebox_override("panel", style)
	close_button.pressed.connect(_on_close_pressed)
	if EmpireManager == null:
		title_label.text = "Colonies"
		return
	_player_empire = EmpireManager.get_player_empire()
	if _player_empire == null:
		title_label.text = "Colonies"
		return
	title_label.text = "Planets & Sectors"
	_populate_list()


func set_manage_callback(callback: Callable) -> void:
	_on_manage_requested = callback


func _populate_list() -> void:
	for c in list_container.get_children():
		c.queue_free()
	if _player_empire == null or GalaxyManager == null:
		return
	for col in _player_empire.colonies:
		var sys: StarSystem = GalaxyManager.get_system(col.system_id)
		var planet_name: String = "Planet %d" % col.planet_index
		if sys != null and col.planet_index >= 0 and col.planet_index < sys.planets.size():
			planet_name = sys.planets[col.planet_index].name_key
		var system_name: String = sys.name_key if sys != null else "?"
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl: Label = Label.new()
		lbl.text = "%s — %s  (%d pops)" % [planet_name, system_name, col.pop_count]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var btn: Button = Button.new()
		btn.text = "Manage"
		btn.pressed.connect(_on_manage_colony.bind(col.system_id, col.planet_index))
		row.add_child(btn)
		list_container.add_child(row)


func _on_manage_colony(system_id: int, planet_index: int) -> void:
	if _on_manage_requested.is_valid():
		_on_manage_requested.call(system_id, planet_index)
	closed.emit()


func _on_close_pressed() -> void:
	closed.emit()
