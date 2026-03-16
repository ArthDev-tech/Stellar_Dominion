extends DraggableOverlay
## Technology overlay: current research, progress, tech draw.
## Emits closed when Close is pressed.

signal closed

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Margin/VBox/TitleBar/CloseButton
@onready var research_label: Label = $Margin/VBox/ContentBox/ResearchLabel
@onready var progress_label: Label = $Margin/VBox/ContentBox/ProgressLabel
@onready var draw_container: HBoxContainer = $Margin/VBox/ContentBox/DrawHBox

var _empire: Empire


func _ready() -> void:
	super._ready()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a0f1c")
	style.border_color = Color("#1e3a5f")
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	add_theme_stylebox_override("panel", style)
	close_button.pressed.connect(_on_close_pressed)
	for i in range(draw_container.get_child_count()):
		var btn: Button = draw_container.get_child(i) as Button
		if btn != null:
			btn.pressed.connect(_on_tech_picked.bind(i))
	_refresh()


func setup(empire: Empire) -> void:
	_empire = empire


func _refresh() -> void:
	if _empire == null or ResearchManager == null:
		research_label.text = "No research data."
		progress_label.text = ""
		return
	if not _empire.current_research_tech_id.is_empty():
		var def: Dictionary = ResearchManager.get_tech_def(_empire.current_research_tech_id)
		var cost: float = float(def.get("cost", 100))
		research_label.text = "%s\n%.0f / %.0f" % [def.get("name_key", "?"), _empire.research_progress, cost]
		progress_label.text = "In progress"
		_draw_tech_buttons(false)
	else:
		var tech_draw: Array = ResearchManager.get_draw(_empire, 3)
		research_label.text = "Choose a tech to research:" if tech_draw.size() > 0 else "No techs available."
		progress_label.text = ""
		_draw_tech_buttons(true)
		for i in draw_container.get_child_count():
			var btn: Button = draw_container.get_child(i) as Button
			if btn != null and i < tech_draw.size():
				btn.visible = true
				btn.text = tech_draw[i].get("name_key", "?")
				btn.set_meta("tech_index", i)
			elif btn != null:
				btn.visible = false


func _draw_tech_buttons(show_choices: bool) -> void:
	var tech_draw: Array = [] if _empire == null or ResearchManager == null else ResearchManager.get_draw(_empire, 3)
	for i in range(draw_container.get_child_count()):
		var btn: Button = draw_container.get_child(i) as Button
		if btn == null:
			continue
		btn.visible = show_choices and i < tech_draw.size()
		if btn.visible and i < tech_draw.size():
			btn.text = tech_draw[i].get("name_key", "?")
			btn.set_meta("tech_index", i)
			btn.set_meta("tech_id", tech_draw[i].get("id", ""))


func _on_tech_picked(button_index: int) -> void:
	if _empire == null or ResearchManager == null or _empire.current_research_tech_id != "":
		return
	var btn: Button = draw_container.get_child(button_index) as Button
	if btn == null or not btn.has_meta("tech_id"):
		return
	_empire.current_research_tech_id = btn.get_meta("tech_id")
	_empire.research_progress = 0.0
	_refresh()


func _on_close_pressed() -> void:
	closed.emit()
