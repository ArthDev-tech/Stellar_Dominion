extends Node2D
## One player ship on the galaxy map: pick target, rotating selection ring, path Line2D.
## Ship is a child of GalaxyMap/ShipsLayer. Lerp uses same galaxy plane as StarSystem.position (see Ship.transit_origin_galaxy).

@export var base_radius: float = 5.0
@export var ring_color: Color = Color(1.0, 0.85, 0.1, 0.9)
@export var ring_width: float = 2.0
@export var ring_radius_offset: float = 4.0

var _ship: Ship
var _is_galaxy_selected: bool = false
var _ring_rotation: float = 0.0
var _path_line: Line2D


func _ready() -> void:
	z_index = 2
	add_to_group("galaxy_ship_icons")
	_is_galaxy_selected = false
	_path_line = Line2D.new()
	_path_line.name = "PathPreviewLine"
	_path_line.width = 2.5
	_path_line.default_color = Color(1.0, 0.85, 0.2, 0.95)
	_path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_path_line)
	_path_line.visible = false


func setup_galaxy_ship(ship: Ship) -> void:
	_ship = ship


func get_galaxy_ship() -> Ship:
	return _ship


func set_galaxy_selected(v: bool) -> void:
	if _is_galaxy_selected == v:
		if v:
			_update_path_line()
		return
	_is_galaxy_selected = v
	_path_line.visible = v
	if v:
		_ring_rotation = 0.0
		_update_path_line()
	else:
		_path_line.clear_points()
	queue_redraw()


func matches_ship_data(sd: ShipData) -> bool:
	return _ship != null and sd.matches_ship(_ship)


func _transit_origin_for_hyperlane(o_sys: StarSystem) -> Vector2:
	if _ship.transit_origin_galaxy_valid:
		return _ship.transit_origin_galaxy
	return o_sys.position


func _process(delta: float) -> void:
	if _ship == null or GalaxyManager == null:
		return
	if _ship.in_hyperlane:
		var o_sys: StarSystem = GalaxyManager.get_system(_ship.system_id)
		var d_sys: StarSystem = GalaxyManager.get_system(_ship.hyperlane_to_system_id)
		if o_sys != null and d_sys != null:
			var t: float = clampf(_ship.hyperlane_progress, 0.0, 1.0)
			var origin_w: Vector2 = _transit_origin_for_hyperlane(o_sys)
			var jw: Vector2 = ShipMoveOrder.compute_jump_point_galaxy(o_sys.position, d_sys.position) if ShipMoveOrder != null else d_sys.position
			global_position = origin_w.lerp(jw, t)
		if _is_galaxy_selected:
			_ring_rotation += deg_to_rad(30.0) * delta
			_update_path_line()
			queue_redraw()
		return
	if _is_galaxy_selected:
		_ring_rotation += deg_to_rad(30.0) * delta
		_update_path_line()
		queue_redraw()


func _update_path_line() -> void:
	_path_line.clear_points()
	if not _is_galaxy_selected or _ship == null or GalaxyManager == null:
		return
	if _ship.in_hyperlane:
		var o_sys: StarSystem = GalaxyManager.get_system(_ship.system_id)
		var dest: StarSystem = GalaxyManager.get_system(_ship.hyperlane_to_system_id)
		if dest == null or o_sys == null or ShipMoveOrder == null:
			return
		var jw: Vector2 = ShipMoveOrder.compute_jump_point_galaxy(o_sys.position, dest.position)
		_path_line.add_point(Vector2.ZERO)
		_path_line.add_point(jw - global_position)
		return
	var path_ids: Array[int] = [_ship.system_id]
	if _ship.target_system_id >= 0:
		path_ids.append(_ship.target_system_id)
	for i in _ship.path_queue.size():
		path_ids.append(_ship.path_queue[i])
	if path_ids.size() < 2:
		return
	for sid in path_ids:
		var sys: StarSystem = GalaxyManager.get_system(sid)
		if sys != null:
			_path_line.add_point(sys.position - position)


func _draw() -> void:
	var color: Color = Color(0.85, 0.82, 0.6, 1.0)
	var display_type: String = "construction"
	if _ship != null and EconomyManager != null:
		display_type = EconomyManager.get_ship_display_type(_ship.design_id)
	match display_type:
		"science":
			color = Color(0.4, 0.7, 1.0, 1.0)
		"construction":
			color = Color(0.95, 0.85, 0.3, 1.0)
		_:
			color = Color(0.95, 0.35, 0.3, 1.0)
	match display_type:
		"science":
			draw_circle(Vector2.ZERO, base_radius, color)
		"construction":
			draw_rect(Rect2(-base_radius, -base_radius, base_radius * 2.0, base_radius * 2.0), color)
		_:
			var tri: PackedVector2Array = [
				Vector2(base_radius, -base_radius),
				Vector2(-base_radius, base_radius),
				Vector2(base_radius, base_radius)
			]
			draw_colored_polygon(tri, color)
	if _is_galaxy_selected:
		var rr: float = base_radius + ring_radius_offset
		draw_arc(Vector2.ZERO, rr, _ring_rotation, _ring_rotation + TAU * 0.92, 48, ring_color, ring_width, true)
