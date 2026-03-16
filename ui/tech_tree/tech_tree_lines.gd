@tool
extends Control
## Draws prerequisite links between tech cards. Reads meta "tech_centers", "tech_prereqs", and optional "tech_branches".
## In the editor, builds that data from sibling card nodes and techs.json so connection lines are visible when editing the tree.

@export var line_width: float = 2.5
@export var arrow_size: float = 6.0
@export var card_half_w: float = 130.0
@export var card_half_h: float = 70.0
@export var branch_color_physical: Color = Color(0.0, 0.78, 1.0)
@export var branch_color_social: Color = Color(1.0, 0.77, 0.3)
@export var branch_color_xenological: Color = Color(0.71, 0.3, 1.0)
## Editor-defined links: each string is "from_tech_id|to_tech_id" (e.g. tech_basic_energy|tech_my_new_tech). Merged with techs.json prerequisites for drawing.
@export var extra_connections: PackedStringArray = []

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_build_editor_line_data")


var _editor_refresh_timer: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not is_inside_tree():
			return
		_editor_refresh_timer += delta
		if _editor_refresh_timer >= 0.4:
			_editor_refresh_timer = 0.0
			_build_editor_line_data()


func _build_editor_line_data() -> void:
	if not is_inside_tree():
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var centers: Dictionary = {}
	var prereqs: Dictionary = {}
	var branches: Dictionary = {}
	# Load techs.json for prereqs and branch
	var path := ProjectPaths.DATA_TECHS
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Array:
				for t in json.data:
					var tid: String = t.get("id", "")
					if tid.is_empty():
						continue
					var pre: Array = t.get("prerequisites", [])
					if pre.size() > 0:
						prereqs[tid] = pre
					var cat: int = int(t.get("category", 0))
					branches[tid] = ["physical", "social", "xenological"][clampi(cat, 0, 2)]
			f.close()
	# From sibling nodes (cards) get positions; use control size when available for correct line endpoints
	for c in parent.get_children():
		if c == self or c.name == "Background" or c.name.begins_with("BranchLabel"):
			continue
		if c is Control and c.name.begins_with("tech_"):
			var card: Control = c as Control
			var pos: Vector2 = card.position
			var sz: Vector2 = card.size
			if sz.x <= 0 or sz.y <= 0:
				sz = card.custom_minimum_size
			if sz.x > 0 and sz.y > 0:
				centers[c.name] = pos + sz * 0.5
			else:
				centers[c.name] = pos + Vector2(card_half_w, card_half_h)
	# Merge editor-defined extra connections (format: "from_id|to_id")
	for conn in extra_connections:
		var parts: PackedStringArray = conn.split("|")
		if parts.size() != 2:
			continue
		var from_id: String = parts[0].strip_edges()
		var to_id: String = parts[1].strip_edges()
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not prereqs.has(to_id):
			prereqs[to_id] = []
		var arr: Array = prereqs[to_id]
		if from_id in arr:
			continue
		arr.append(from_id)
	set_meta("tech_centers", centers)
	set_meta("tech_prereqs", prereqs)
	set_meta("tech_branches", branches)
	set_meta("card_half_size", Vector2(card_half_w, card_half_h))
	queue_redraw()


func _get_branch_colors() -> Dictionary:
	return {
		"physical": branch_color_physical,
		"social": branch_color_social,
		"xenological": branch_color_xenological,
	}


func _draw() -> void:
	var centers: Dictionary = get_meta("tech_centers", {})
	var prereqs: Dictionary = get_meta("tech_prereqs", {})
	var branches: Dictionary = get_meta("tech_branches", {})
	for tid in prereqs:
		var to_center: Vector2 = centers.get(tid, Vector2.ZERO)
		for pid in prereqs[tid]:
			var from_center: Vector2 = centers.get(pid, Vector2.ZERO)
			if from_center.distance_squared_to(to_center) < 4.0:
				continue
			var line_col: Color = _get_branch_colors().get(branches.get(tid, "physical"), branch_color_physical)
			line_col.a = 0.9
			_draw_stepped_line(from_center, to_center, line_col)


func _draw_stepped_line(from_pos: Vector2, to_pos: Vector2, line_color: Color) -> void:
	# L-shaped path: horizontal from prereq edge, then vertical, then into dependent edge
	var half_size: Vector2 = get_meta("card_half_size", Vector2(130.0, 70.0))
	var half_w: float = half_size.x
	var half_h: float = half_size.y
	var from_out: Vector2 = _edge_point(from_pos, to_pos, half_w, half_h, true)
	var to_in: Vector2 = _edge_point(to_pos, from_pos, half_w, half_h, false)
	var mid_x: float = (from_out.x + to_in.x) * 0.5
	var pt1: Vector2 = Vector2(mid_x, from_out.y)
	var pt2: Vector2 = Vector2(mid_x, to_in.y)
	# Shadow for depth
	var shadow_col: Color = Color(0, 0, 0, 0.3)
	_draw_line_strip([from_out, Vector2(pt1.x + 1, pt1.y), Vector2(pt2.x + 1, pt2.y), to_in], shadow_col, line_width + 2.0)
	# Main stepped line
	_draw_line_strip([from_out, pt1, pt2, to_in], line_color, line_width)
	# Arrow at dependent end (direction = from pt2 toward to_in)
	_draw_arrow(to_in, pt2, line_color)


func _edge_point(center: Vector2, other: Vector2, half_w: float, half_h: float, _from_prereq: bool) -> Vector2:
	var dx: float = other.x - center.x
	var dy: float = other.y - center.y
	var out: Vector2 = center
	if abs(dx) > abs(dy):
		out.x = center.x + sign(dx) * half_w
	else:
		out.y = center.y + sign(dy) * half_h
	return out


func _draw_line_strip(points: Array, col: Color, width: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		_draw_thick_line(points[i], points[i + 1], col, width)


func _draw_thick_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	if width <= 1.0:
		draw_line(from, to, color)
		return
	var dir: Vector2 = (to - from).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * (width * 0.5)
	var pts: PackedVector2Array = [from + perp, from - perp, to - perp, to + perp]
	draw_colored_polygon(pts, color)


func _draw_arrow(tip: Vector2, from_dir: Vector2, color: Color) -> void:
	var dir: Vector2 = (tip - from_dir).normalized()
	if dir.length_squared() < 0.01:
		return
	var back: Vector2 = tip - dir * arrow_size
	var right: Vector2 = Vector2(dir.y, -dir.x) * (arrow_size * 0.6)
	var pts: PackedVector2Array = [tip, back + right, back - right]
	draw_colored_polygon(pts, color)
	draw_polyline(pts, color.darkened(0.25))
	draw_line(pts[1], pts[2], color.darkened(0.25))
