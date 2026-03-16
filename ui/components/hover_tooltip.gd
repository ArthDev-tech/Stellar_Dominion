extends PanelContainer
## Reusable mouse-over tooltip. Call show_tooltip(title, body, screen_pos) and hide_tooltip().
## Add to a CanvasLayer so it draws above other UI. Uses mouse_filter IGNORE so it doesn't block input.

const PADDING := 12
const OFFSET_FROM_CURSOR := Vector2(14, 14)
const MAX_WIDTH := 320

var _title_label: Label
var _body_label: Label
var _container: MarginContainer
var _vbox: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 1000  # Draw above planet view and all other overlay windows
	_container = MarginContainer.new()
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_container)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.2, 0.96)
	style.border_color = Color(0.35, 0.5, 0.7, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(PADDING)
	add_theme_stylebox_override("panel", style)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_container.add_child(_vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size.x = MAX_WIDTH - PADDING * 2
	_vbox.add_child(_title_label)
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 12)
	_body_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size.x = MAX_WIDTH - PADDING * 2
	_vbox.add_child(_body_label)


func show_tooltip(title: String, body: String, screen_position: Vector2) -> void:
	_title_label.text = title
	_body_label.text = body
	visible = true
	call_deferred("_position_near", screen_position)


func _position_near(screen_position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = screen_position + OFFSET_FROM_CURSOR
	# Keep on screen
	if position.x + size.x > viewport_size.x - 8:
		position.x = screen_position.x - size.x - OFFSET_FROM_CURSOR.x
	if position.y + size.y > viewport_size.y - 8:
		position.y = viewport_size.y - size.y - 8
	if position.x < 8:
		position.x = 8
	if position.y < 8:
		position.y = 8


func hide_tooltip() -> void:
	visible = false


