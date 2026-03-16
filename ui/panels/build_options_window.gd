extends PanelContainer
## Standalone window that opens beside planet view to show build/specialize options.
## Planet view instantiates this, adds it to the overlay, positions it, and calls open().

@onready var title_label: Label = $VBox/TitleLabel
@onready var options_list: VBoxContainer = $VBox/ScrollContainer/OptionsList

var _get_label: Callable
var _on_select: Callable


func open(title: String, ids: Array, get_label: Callable, on_select: Callable) -> void:
	title_label.text = title
	_get_label = get_label
	_on_select = on_select
	for c in options_list.get_children():
		c.queue_free()
	for id_str in ids:
		if (id_str is String) and (id_str as String).is_empty():
			continue
		var btn: Button = Button.new()
		btn.text = get_label.call(id_str)
		btn.custom_minimum_size.y = 36
		var the_id: String = id_str as String
		btn.pressed.connect(_on_option_pressed.bind(the_id))
		options_list.add_child(btn)


func _on_option_pressed(id_str: String) -> void:
	if _on_select.is_valid():
		_on_select.call(id_str)
	queue_free()
