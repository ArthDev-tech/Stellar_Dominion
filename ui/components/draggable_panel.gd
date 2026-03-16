class_name DraggablePanel
extends PanelContainer
## Reusable panel: drag-by-title-bar and optional close button.
## Uses existing nodes named TitleBar (drag handle) and CloseButton — no content wrapping.

@export var drag_handle_node_name: String = "TitleBar"
@export var close_button_node_name: String = "CloseButton"
## Fallback when no node named drag_handle_node_name is found (e.g. path to title bar).
@export var existing_drag_handle_path: NodePath = NodePath()

var _dragging := false
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Find drag handle by name, then by path
	var handle: Control = find_child(drag_handle_node_name, true, false) as Control
	if handle == null and not existing_drag_handle_path.is_empty():
		handle = get_node_or_null(existing_drag_handle_path) as Control
	if handle == null:
		var in_group: Array = get_tree().get_nodes_in_group("drag_handle")
		for n in in_group:
			if n is Control and is_ancestor_of(n):
				handle = n as Control
				break
	if handle != null:
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		if not handle.gui_input.is_connected(_on_handle_input):
			handle.gui_input.connect(_on_handle_input)
		handle.mouse_default_cursor_shape = Control.CURSOR_MOVE

	# Wire close button by name or group
	var close_btn: Button = find_child(close_button_node_name, true, false) as Button
	if close_btn == null:
		var in_group: Array = get_tree().get_nodes_in_group("close_button")
		for n in in_group:
			if n is Button and is_ancestor_of(n):
				close_btn = n as Button
				break
	if close_btn != null:
		if close_btn.pressed.is_connected(_on_close):
			close_btn.pressed.disconnect(_on_close)
		close_btn.pressed.connect(_on_close)


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_offset = global_position - get_global_mouse_position()


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() + _drag_offset


func _on_close() -> void:
	hide()
	var tree: SceneTree = get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("dim_overlay"):
			if is_instance_valid(node) and node is CanvasItem:
				(node as CanvasItem).hide()
