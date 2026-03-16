class_name DraggableOverlay
extends DraggablePanel
## Base for overlay windows: boxed panel style and drag-by-title-bar.
## Set drag_handle_path to the title bar (e.g. "Margin/VBox/TitleBar") so dragging it moves the window.

@export var drag_handle_path: NodePath = NodePath()


func _ready() -> void:
	if not drag_handle_path.is_empty():
		existing_drag_handle_path = drag_handle_path
	super._ready()
	_apply_panel_style()


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.2, 0.98)
	style.border_color = Color(0.35, 0.4, 0.55, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style)
