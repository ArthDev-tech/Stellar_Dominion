extends Node2D
## Draws one star system on the galaxy map; highlights when selected. Empire home / fallen empire = colored.
## Draws small indicators for player ships (by type: science, construction, military) and stations.

const RADIUS := 8.0
const SELECTED_RADIUS := 12.0
const FALLEN_EMPIRE_COLOR: Color = Color(0.5, 0.2, 0.6, 1.0)
const INDICATOR_Y_OFFSET := 14.0  ## Below star center
const INDICATOR_SIZE := 3.0
const INDICATOR_SELECTED_SCALE := 1.5
const INDICATOR_SHADOW_OFFSET := Vector2(1.5, 1.5)
const INDICATOR_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const SCIENCE_COLOR: Color = Color(0.4, 0.7, 1.0, 1.0)
const CONSTRUCTION_COLOR: Color = Color(0.95, 0.85, 0.3, 1.0)
const MILITARY_COLOR: Color = Color(0.95, 0.35, 0.3, 1.0)
const STATION_COLOR: Color = Color(0.9, 0.9, 0.95, 1.0)
const COLONIZABLE_COLOR: Color = Color(0.3, 0.85, 0.5, 1.0)
const COLONIZABLE_ICON_OFFSET := 10.0  ## Above star center
const COLONIZABLE_ICON_SIZE := 3.5

func _draw() -> void:
	var id: int = get_meta("system_id", -1)
	var selected: bool = (GameState != null and GameState.selected_system_id == id)
	var r: float = SELECTED_RADIUS if selected else RADIUS
	var color: Color
	if selected:
		color = Color(1.0, 0.95, 0.7, 1.0)
	elif EmpireManager != null:
		var emp: Empire = EmpireManager.get_empire_for_home_system(id)
		if emp != null:
			color = emp.color
		elif _is_fallen_empire_system(id):
			color = FALLEN_EMPIRE_COLOR
		else:
			color = Color(0.85, 0.82, 0.6, 0.95)
	else:
		color = Color(0.85, 0.82, 0.6, 0.95)
	draw_circle(Vector2.ZERO, r, color)
	if selected:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 1.0, 0.5, 0.8), 2.0)
	_draw_ship_and_station_indicators(id, r)
	if GalaxyManager != null and GalaxyManager.system_has_colonizable_planet(id):
		_draw_colonizable_icon(r)


func _draw_ship_and_station_indicators(system_id: int, star_radius: float) -> void:
	if EmpireManager == null:
		return
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return
	var science_count: int = 0
	var construction_count: int = 0
	var military_count: int = 0
	for s in player_emp.ships:
		var ship: Ship = s as Ship
		if ship == null or ship.system_id != system_id or ship.in_hyperlane:
			continue
		var display_type: String = "construction"
		if EconomyManager != null:
			display_type = EconomyManager.get_ship_display_type(ship.design_id)
		match display_type:
			"science":
				science_count += 1
			"construction":
				construction_count += 1
			_:
				military_count += 1
	var station_count: int = player_emp.get_stations_in_system(system_id).size()
	var base_y: float = star_radius + INDICATOR_Y_OFFSET
	var dx: float = 8.0
	var highlighted: String = get_meta("highlighted_indicator", "")
	# Science (circle), Construction (square), Military (triangle), Station (diamond)
	if science_count > 0:
		_draw_indicator_circle(Vector2(-1.5 * dx, base_y), SCIENCE_COLOR, highlighted == "science")
	if construction_count > 0:
		_draw_indicator_rect(Vector2(-0.5 * dx, base_y), CONSTRUCTION_COLOR, highlighted == "construction")
	if military_count > 0:
		_draw_indicator_triangle(Vector2(0.5 * dx, base_y), MILITARY_COLOR, highlighted == "military")
	if station_count > 0:
		_draw_indicator_diamond(Vector2(1.5 * dx, base_y), STATION_COLOR, highlighted == "station")


func _draw_indicator_circle(center: Vector2, color: Color, selected: bool) -> void:
	var r: float = INDICATOR_SIZE * (INDICATOR_SELECTED_SCALE if selected else 1.0)
	if selected:
		draw_circle(center + INDICATOR_SHADOW_OFFSET, r, INDICATOR_SHADOW_COLOR)
	draw_circle(center, r, color)


func _draw_indicator_rect(center: Vector2, color: Color, selected: bool) -> void:
	var s: float = INDICATOR_SIZE * (INDICATOR_SELECTED_SCALE if selected else 1.0)
	var half: float = s
	var rect: Rect2 = Rect2(center.x - half, center.y - half, half * 2.0, half * 2.0)
	if selected:
		draw_rect(Rect2(rect.position + INDICATOR_SHADOW_OFFSET, rect.size), INDICATOR_SHADOW_COLOR)
	draw_rect(rect, color)


func _draw_indicator_triangle(center: Vector2, color: Color, selected: bool) -> void:
	var s: float = INDICATOR_SIZE * (INDICATOR_SELECTED_SCALE if selected else 1.0)
	var tri: PackedVector2Array = [
		center + Vector2(0.0, -s),
		center + Vector2(-s, s),
		center + Vector2(s, s)
	]
	if selected:
		var shadow_tri: PackedVector2Array = [tri[0] + INDICATOR_SHADOW_OFFSET, tri[1] + INDICATOR_SHADOW_OFFSET, tri[2] + INDICATOR_SHADOW_OFFSET]
		draw_colored_polygon(shadow_tri, INDICATOR_SHADOW_COLOR)
	draw_colored_polygon(tri, color)


func _draw_indicator_diamond(center: Vector2, color: Color, selected: bool) -> void:
	var s: float = INDICATOR_SIZE * (INDICATOR_SELECTED_SCALE if selected else 1.0)
	var diamond_center: Vector2 = Vector2(center.x, center.y + INDICATOR_SIZE)
	var diamond: PackedVector2Array = [
		diamond_center + Vector2(0.0, -s),
		diamond_center + Vector2(s, 0.0),
		diamond_center + Vector2(0.0, s),
		diamond_center + Vector2(-s, 0.0)
	]
	if selected:
		var shadow_diamond: PackedVector2Array = [diamond[0] + INDICATOR_SHADOW_OFFSET, diamond[1] + INDICATOR_SHADOW_OFFSET, diamond[2] + INDICATOR_SHADOW_OFFSET, diamond[3] + INDICATOR_SHADOW_OFFSET]
		draw_colored_polygon(shadow_diamond, INDICATOR_SHADOW_COLOR)
	draw_colored_polygon(diamond, color)


func _draw_colonizable_icon(star_radius: float) -> void:
	var pos: Vector2 = Vector2(0.0, -star_radius - COLONIZABLE_ICON_OFFSET)
	draw_circle(pos, COLONIZABLE_ICON_SIZE, COLONIZABLE_COLOR)


func _is_fallen_empire_system(system_id: int) -> bool:
	if GalaxyManager == null or GalaxyManager.galaxy == null:
		return false
	for fe in GalaxyManager.galaxy.fallen_empires:
		if fe.owns_system(system_id):
			return true
	return false
