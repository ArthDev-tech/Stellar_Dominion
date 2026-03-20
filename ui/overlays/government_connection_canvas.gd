extends Control
## Draws connection lines from policy dots to key holder dots via routing zone between key row and categories.
## Overlay root is get_parent().get_parent().get_parent() (exposes policy_dot_centers, holder_dot_centers, selected_item).

const COLOR_POSITIVE: Color = Color(0.388, 0.6, 0.133, 1.0)
const COLOR_NEGATIVE: Color = Color(0.886, 0.294, 0.29, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Resolve overlay root (canvas parent is _canvas_area -> vbox -> overlay).
	var overlay: Node = get_parent()
	if overlay != null:
		overlay = overlay.get_parent()
	if overlay != null:
		overlay = overlay.get_parent()
	if overlay == null or not "policy_dot_centers" in overlay or not "holder_dot_centers" in overlay:
		return
	var policy_dots: Dictionary = overlay.policy_dot_centers
	var holder_dots: Dictionary = overlay.holder_dot_centers
	var selected: Dictionary = overlay.selected_item if "selected_item" in overlay else {}
	if GovernmentManager == null:
		return
	var connections: Array = GovernmentManager.get_active_connections()
	var normal_links: Array[Dictionary] = []
	var highlighted_links: Array[Dictionary] = []
	for link in connections:
		var pid: StringName = link.get("policy_id", &"")
		var hid: StringName = link.get("holder_id", &"")
		if not policy_dots.has(pid) or not holder_dots.has(hid):
			continue
		var involves_selected: bool = (selected.get("type") == "policy" and selected.get("id") == pid) or (selected.get("type") == "holder" and selected.get("id") == hid)
		if involves_selected:
			highlighted_links.append(link)
		else:
			normal_links.append(link)
	var total_drawable: int = normal_links.size() + highlighted_links.size()
	var routing_zone_bottom_y: float = 0.0
	var rz: Control = get_meta("routing_zone", null) as Control
	var xform: Transform2D = get_global_transform_with_canvas().affine_inverse()
	if is_instance_valid(rz):
		# AUDIT: NEEDS REVIEW — RoutingZone is not a child of this canvas; verify coordinate chain if layout changes.
		var gr: Rect2 = rz.get_global_rect()
		var local_cy: float = (xform * gr.get_center()).y
		routing_zone_bottom_y = local_cy + rz.size.y * 0.5
	if total_drawable > 0 and is_instance_valid(rz):
		draw_line(Vector2(0.0, routing_zone_bottom_y), Vector2(size.x, routing_zone_bottom_y), Color(1, 1, 1, 0.04), 1.0)
	for link in normal_links:
		_draw_connection(link, policy_dots, holder_dots, false, routing_zone_bottom_y, is_instance_valid(rz))
	for link in highlighted_links:
		_draw_connection(link, policy_dots, holder_dots, true, routing_zone_bottom_y, is_instance_valid(rz))


func _draw_connection(link: Dictionary, policy_dots: Dictionary, holder_dots: Dictionary, highlighted: bool, routing_zone_bottom_y: float, use_routing: bool) -> void:
	var pid: StringName = link.get("policy_id", &"")
	var hid: StringName = link.get("holder_id", &"")
	var stored_direction: int = link.get("direction", 1)
	var stored_strength: float = link.get("strength", 0.0)
	var from_global: Vector2 = policy_dots[pid]
	var to_global: Vector2 = holder_dots[hid]
	var xform = get_global_transform_with_canvas().affine_inverse()
	var from_pos: Vector2 = xform * from_global
	var to_pos: Vector2 = xform * to_global
	var slider_val: float = GovernmentManager.get_policy_value(pid)
	var direction: int = stored_direction
	var strength: float = stored_strength
	var lever: PolicyLever = GovernmentManager.get_policy_lever(pid)
	if lever != null and lever.dynamic_direction:
		var effective_value: float = clampf((slider_val - 0.25) * 2.0, -1.0, 1.0)
		if absf(effective_value) < 0.05:
			return
		direction = int(signf(effective_value)) * stored_direction
		strength = absf(effective_value) * stored_strength
	var alpha: float = strength * (slider_val if (lever == null or not lever.dynamic_direction) else 1.0) * 0.65
	if highlighted:
		alpha = 0.95
	else:
		alpha = clampf(alpha, 0.0, 1.0)
	var width: float = 0.8 + strength * 1.5
	if highlighted:
		width = 1.5 + strength * 2.0
	var col: Color
	if direction >= 1:
		col = Color(COLOR_POSITIVE.r, COLOR_POSITIVE.g, COLOR_POSITIVE.b, alpha)
	else:
		col = Color(COLOR_NEGATIVE.r, COLOR_NEGATIVE.g, COLOR_NEGATIVE.b, alpha)
	var c1: Vector2
	var c2: Vector2
	if use_routing:
		c1 = Vector2(from_pos.x, routing_zone_bottom_y - 10.0)
		c2 = Vector2(to_pos.x, routing_zone_bottom_y + 10.0)
	else:
		c1 = Vector2(from_pos.x, lerpf(from_pos.y, to_pos.y, 0.4))
		c2 = Vector2(to_pos.x, lerpf(from_pos.y, to_pos.y, 0.6))
	_draw_cubic_bezier(from_pos, to_pos, c1, c2, col, width)


func _draw_cubic_bezier(p0: Vector2, p3: Vector2, p1: Vector2, p2: Vector2, col: Color, width: float) -> void:
	var steps: int = 24
	var prev: Vector2 = p0
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var t2: float = t * t
		var t3: float = t2 * t
		var u: float = 1.0 - t
		var u2: float = u * u
		var u3: float = u2 * u
		var p: Vector2 = u3 * p0 + 3.0 * u2 * t * p1 + 3.0 * u * t2 * p2 + t3 * p3
		draw_line(prev, p, col, width)
		prev = p
