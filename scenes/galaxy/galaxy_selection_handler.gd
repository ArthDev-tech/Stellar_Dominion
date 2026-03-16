extends Control
## Handles LMB click and box selection for ships on the galaxy map. Draws selection rectangle.

signal selection_changed(selected_ships: Array)

@export var DRAG_THRESHOLD: float = 8.0
@export var CLICK_RADIUS: float = 24.0
@export var box_select_fill_color: Color = Color(0.27, 0.67, 1.0, 0.08)
@export var box_select_border_color: Color = Color(0.27, 0.67, 1.0, 0.55)
@export var box_select_border_width: float = 1.5

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _selection_rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Returns true if a box drag is in progress (release should perform box select, not indicator click).
func is_box_drag_in_progress() -> bool:
	return _is_dragging


## Called by GameScene from _unhandled_input. Returns true if the event was consumed (root should not run system selection).
## release_screen_position: optional viewport position to use for click-select on LMB release (e.g. e.position from the event).
func process_input(event: InputEvent, release_screen_position: Variant = null) -> bool:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index != MOUSE_BUTTON_LEFT:
			return false
		if e.pressed:
			_drag_start = get_viewport().get_mouse_position()
			_is_dragging = false
			_selection_rect = Rect2()
			queue_redraw()
			return true
		else:
			if _is_dragging:
				_perform_box_select(_selection_rect)
				_is_dragging = false
				_selection_rect = Rect2()
				queue_redraw()
				return true
			else:
				var click_pos: Vector2 = get_viewport().get_mouse_position()
				if release_screen_position is Vector2:
					click_pos = release_screen_position
				var consumed: bool = _perform_click_select(click_pos)
				_is_dragging = false
				_selection_rect = Rect2()
				queue_redraw()
				return consumed
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pos: Vector2 = get_viewport().get_mouse_position()
			if not _is_dragging and _drag_start.distance_to(pos) > DRAG_THRESHOLD:
				_is_dragging = true
			if _is_dragging:
				var min_p := Vector2(minf(_drag_start.x, pos.x), minf(_drag_start.y, pos.y))
				var max_p := Vector2(maxf(_drag_start.x, pos.x), maxf(_drag_start.y, pos.y))
				_selection_rect = Rect2(min_p, max_p - min_p)
				queue_redraw()
			return true
	return false


func _draw() -> void:
	if _is_dragging and _selection_rect.size.x > 0 and _selection_rect.size.y > 0:
		var inv := get_global_transform_with_canvas().affine_inverse()
		var local_pos: Vector2 = inv * _selection_rect.position
		var local_end: Vector2 = inv * _selection_rect.end
		var local_rect := Rect2(local_pos, local_end - local_pos)
		draw_rect(local_rect, box_select_fill_color)
		draw_rect(local_rect, box_select_border_color, false)


func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()


func _perform_box_select(screen_rect: Rect2) -> void:
	var cam: Camera2D = _get_camera()
	if cam == null or SelectionManager == null:
		return
	var xform := cam.get_screen_transform().affine_inverse()
	var p0: Vector2 = xform * screen_rect.position
	var p1: Vector2 = xform * Vector2(screen_rect.end.x, screen_rect.position.y)
	var p2: Vector2 = xform * screen_rect.end
	var p3: Vector2 = xform * Vector2(screen_rect.position.x, screen_rect.end.y)
	var min_w: Vector2 = p0.min(p1).min(p2).min(p3)
	var max_w: Vector2 = p0.max(p1).max(p2).max(p3)
	var world_rect := Rect2(min_w, max_w - min_w)
	var nodes: Array = get_tree().get_nodes_in_group("galaxy_ships")
	var collected: Array = []
	for node in nodes:
		var n: Node2D = node as Node2D
		if n != null and world_rect.has_point(n.global_position):
			collected.append(n)
	if Input.is_key_pressed(KEY_SHIFT):
		SelectionManager.add_to_selection(collected)
	else:
		SelectionManager.set_selection(collected)
	selection_changed.emit(SelectionManager.selected_ships)
	get_viewport().set_input_as_handled()


## Returns true if a ship was selected (event consumed), false if cleared (caller may run system selection).
func _perform_click_select(screen_pos: Vector2) -> bool:
	if SelectionManager == null:
		return false
	var cam: Camera2D = _get_camera()
	if cam == null:
		return false
	var nodes: Array = get_tree().get_nodes_in_group("galaxy_ships")
	var best: Node2D = null
	var best_dist: float = CLICK_RADIUS
	for node in nodes:
		var n: Node2D = node as Node2D
		if n == null:
			continue
		var screen_p: Vector2 = cam.get_screen_transform() * n.global_position
		var d: float = screen_pos.distance_to(screen_p)
		if d < best_dist:
			best_dist = d
			best = n
	if best != null:
		if Input.is_key_pressed(KEY_SHIFT):
			SelectionManager.add_to_selection([best])
		else:
			SelectionManager.set_selection([best])
		selection_changed.emit(SelectionManager.selected_ships)
		get_viewport().set_input_as_handled()
		return true
	else:
		SelectionManager.clear_selection()
		return false
