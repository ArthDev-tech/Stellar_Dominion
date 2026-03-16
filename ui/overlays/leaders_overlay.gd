extends DraggableOverlay
## Leaders overlay: list leaders, optional Recruit.
## Emits closed when Close is pressed.

signal closed

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Margin/VBox/TitleBar/CloseButton
@onready var list_container: VBoxContainer = $Margin/VBox/ScrollContainer/ListContainer
@onready var recruit_button: Button = $Margin/VBox/RecruitButton

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
	recruit_button.pressed.connect(_on_recruit_pressed)
	_refresh()


func setup(empire: Empire) -> void:
	_empire = empire
	_refresh()


func _refresh() -> void:
	if list_container == null:
		return
	for c in list_container.get_children():
		c.queue_free()
	if _empire == null:
		title_label.text = "Leaders"
		return
	title_label.text = "Leaders"
	for l in _empire.leaders:
		var type_name: String = Leader.get_type_name(l.leader_type) if l.leader_type >= 0 else "?"
		var line: Label = Label.new()
		line.text = "%s — %s (Lv.%d)" % [l.name_key, type_name, l.level]
		list_container.add_child(line)


func _on_recruit_pressed() -> void:
	if _empire == null or LeaderManager == null:
		return
	LeaderManager.recruit_leader(_empire, Leader.LeaderType.SCIENTIST)
	_refresh()


func _on_close_pressed() -> void:
	closed.emit()
