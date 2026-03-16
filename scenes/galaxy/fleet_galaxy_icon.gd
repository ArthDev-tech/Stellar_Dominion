extends Node2D
## One consolidated fleet indicator on the galaxy map. Circle by power tier, ship count badge, dominant class icon.

@export_group("Fleet Icon")
@export var fleet_data: FleetData
@export var empire_color: Color = Color(0.4, 0.7, 1.0)
@export var base_radius: float = 10.0
@export var power_tier_small: float = 500.0
@export var power_tier_medium: float = 2000.0
@export var radius_small: float = 8.0
@export var radius_medium: float = 12.0
@export var radius_large: float = 18.0
@export var border_width: float = 1.5
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.4)

@export_group("Selection Visual")
var _selected: bool = false
@export var selected: bool:
	get: return _selected
	set(v): _selected = v; queue_redraw()
@export var halo_color: Color = Color(0.27, 0.67, 1.0, 0.6)
@export var halo_radius_offset: float = 6.0
@export var pulse_speed: float = 2.5
@export var pulse_min_alpha: float = 0.3
@export var pulse_max_alpha: float = 0.75

var _pulse_timer: float = 0.0


func _ready() -> void:
	add_to_group("galaxy_ships")


func _process(delta: float) -> void:
	if _selected:
		_pulse_timer += delta
		queue_redraw()


func _get_radius() -> float:
	if fleet_data == null:
		return radius_small
	var power: float = fleet_data.get_total_power()
	if power < power_tier_small:
		return radius_small
	if power < power_tier_medium:
		return radius_medium
	return radius_large


func _get_dominant_class() -> String:
	if fleet_data == null or fleet_data.ships.is_empty():
		return "construction"
	var counts: Dictionary = {}
	for s in fleet_data.ships:
		if s == null:
			continue
		var c: String = s.ship_class if s.ship_class != "" else "construction"
		counts[c] = counts.get(c, 0) + 1
	var best_class: String = "construction"
	var best_count: int = 0
	for k in counts:
		if counts[k] > best_count:
			best_count = counts[k]
			best_class = k
	return best_class


func _draw() -> void:
	var r: float = _get_radius()
	# Pulsing halo when selected
	if _selected:
		var pulse_alpha: float = lerp(pulse_min_alpha, pulse_max_alpha, (sin(_pulse_timer * pulse_speed) + 1.0) / 2.0)
		var halo: Color = Color(halo_color.r, halo_color.g, halo_color.b, pulse_alpha)
		draw_circle(Vector2.ZERO, r + halo_radius_offset, halo)
	# Filled circle (empire color)
	draw_circle(Vector2.ZERO, r, empire_color)
	# Border ring
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, border_color, border_width)
	# Ship count label (top-right of circle)
	var count_str: String = "0"
	if fleet_data != null:
		count_str = str(fleet_data.ships.size())
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var label_pos: Vector2 = Vector2(r * 0.6, -r * 0.6)
	draw_string(font, label_pos, count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# Dominant class shape inside circle (small, centered slightly below)
	var display_type: String = _get_dominant_class()
	# Normalize to science/construction/military for shape
	if display_type != "science" and display_type != "construction" and display_type != "military":
		if display_type == "constructor":
			display_type = "construction"
		else:
			display_type = "military"
	var shape_r: float = r * 0.35
	var center: Vector2 = Vector2(0.0, r * 0.15)
	var icon_color: Color = Color(1.0, 1.0, 1.0, 0.9)
	match display_type:
		"science":
			draw_circle(center, shape_r, icon_color)
		"construction":
			draw_rect(Rect2(center.x - shape_r, center.y - shape_r, shape_r * 2.0, shape_r * 2.0), icon_color)
		_:
			var tri: PackedVector2Array = [
				center + Vector2(shape_r, -shape_r),
				center + Vector2(-shape_r, shape_r),
				center + Vector2(shape_r, shape_r)
			]
			draw_colored_polygon(tri, icon_color)
