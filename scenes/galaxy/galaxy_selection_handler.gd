extends Control
## Handles LMB click and box selection for ships on the galaxy map. Draws selection rectangle.

signal selection_changed(selected_ships: Array)

@export var DRAG_THRESHOLD: float = 8.0
@export var CLICK_RADIUS: float = 28.0
@export var box_select_fill_color: Color = Color(0.27, 0.67, 1.0, 0.08)
@export var box_select_border_color: Color = Color(0.27, 0.67, 1.0, 0.55)
@export var box_select_border_width: float = 1.5

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _selection_rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_drag_visual_state() -> void:
	_is_dragging = false
	_selection_rect = Rect2()
	queue_redraw()


func is_box_drag_in_progress() -> bool:
	return _is_dragging


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
			var was_dragging_box: bool = _is_dragging
			var box_rect: Rect2 = _selection_rect
			var result: bool = false
			if was_dragging_box:
				result = _perform_box_select(box_rect)
			else:
				var click_pos: Vector2 = get_viewport().get_mouse_position()
				if release_screen_position is Vector2:
					click_pos = release_screen_position
				result = _perform_click_select(click_pos)
			_clear_drag_visual_state()
			return result
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
		draw_rect(local_rect, box_select_border_color, false, box_select_border_width)


func _screen_rect_to_world_rect(screen_rect: Rect2) -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null or screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return Rect2()
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var p0: Vector2 = inv * screen_rect.position
	var p1: Vector2 = inv * Vector2(screen_rect.end.x, screen_rect.position.y)
	var p2: Vector2 = inv * screen_rect.end
	var p3: Vector2 = inv * Vector2(screen_rect.position.x, screen_rect.end.y)
	var min_w: Vector2 = p0.min(p1).min(p2).min(p3)
	var max_w: Vector2 = p0.max(p1).max(p2).max(p3)
	return Rect2(min_w, max_w - min_w)


func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()


func _make_ship_data(ship: Ship) -> ShipData:
	var d := ShipData.new()
	if ship == null:
		return d
	d.ship_name = ship.name_key
	d.ship_class = EconomyManager.get_ship_display_type(ship.design_id) if EconomyManager != null else "construction"
	d.galaxy_system_id = ship.system_id
	d.galaxy_empire_id = ship.empire_id
	d.galaxy_selection_instance_id = int(ship.get_instance_id())
	d.transit_time_modifier = ship.transit_time_modifier
	return d


func _ship_data_array_to_variant(ships: Array[ShipData]) -> Array:
	var out: Array = []
	for sd in ships:
		out.append(sd)
	return out


func _perform_box_select(screen_rect: Rect2) -> bool:
	if SelectionManager == null:
		return true
	var cam: Camera2D = _get_camera()
	if cam == null:
		return true
	var world_rect: Rect2 = _screen_rect_to_world_rect(screen_rect)
	var nodes: Array = SelectionManager.get_registered_icons()
	if nodes.is_empty():
		nodes = get_tree().get_nodes_in_group("galaxy_ship_icons")
	var collected: Array[ShipData] = []
	for node in nodes:
		if not is_instance_valid(node) or not node.has_method("get_galaxy_ship"):
			continue
		var n: Node2D = node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		if world_rect.has_point(n.global_position):
			var sh: Ship = node.call("get_galaxy_ship") as Ship
			if sh != null:
				collected.append(_make_ship_data(sh))
	var payload: Array = []
	for sd in collected:
		payload.append(sd)
	if Input.is_key_pressed(KEY_SHIFT):
		SelectionManager.add_to_selection(payload)
	else:
		SelectionManager.set_selection(payload)
	selection_changed.emit(_ship_data_array_to_variant(SelectionManager.selected_ships))
	get_viewport().set_input_as_handled()
	return true


func _perform_click_select(screen_pos: Vector2) -> bool:
	if SelectionManager == null:
		return false
	var cam: Camera2D = _get_camera()
	if cam == null:
		return false
	var nodes: Array = SelectionManager.get_registered_icons()
	if nodes.is_empty():
		nodes = get_tree().get_nodes_in_group("galaxy_ship_icons")
	var best_ship: Ship = null
	var best_dist: float = CLICK_RADIUS
	for node in nodes:
		if not is_instance_valid(node) or not node.has_method("get_galaxy_ship"):
			continue
		var n: Node2D = node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		var screen_p: Vector2 = cam.get_screen_transform() * n.global_position
		var d: float = screen_pos.distance_to(screen_p)
		if d < best_dist:
			best_dist = d
			best_ship = node.call("get_galaxy_ship") as Ship
	if best_ship != null:
		var sd: ShipData = _make_ship_data(best_ship)
		var one: Array = [sd]
		if Input.is_key_pressed(KEY_SHIFT):
			SelectionManager.add_to_selection(one)
		else:
			SelectionManager.set_selection(one)
		selection_changed.emit(_ship_data_array_to_variant(SelectionManager.selected_ships))
		get_viewport().set_input_as_handled()
		return true
	else:
		SelectionManager.clear_selection()
		return false
