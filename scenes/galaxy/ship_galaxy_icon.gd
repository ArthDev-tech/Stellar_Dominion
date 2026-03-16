extends Node2D
## One icon per player ship on the galaxy map. Draws small shape by type; selection halo when selected.

@export var base_radius: float = 3.0

var _selected: bool = false
var pulse_timer: float = 0.0

@export_group("Selection Visual")
var selected: bool:
	get: return _selected
	set(v): _selected = v; queue_redraw()

@export var selection_halo_color: Color = Color(0.27, 0.67, 1.0, 0.6)
@export var selection_halo_radius_offset: float = 6.0
@export var selection_pulse_speed: float = 2.5
@export var selection_pulse_min_alpha: float = 0.3
@export var selection_pulse_max_alpha: float = 0.75


func _process(delta: float) -> void:
	if _selected:
		pulse_timer += delta
		queue_redraw()


func _draw() -> void:
	var ship: Ship = get_meta("ship", null) as Ship
	var color: Color = Color(0.85, 0.82, 0.6, 1.0)
	var display_type: String = "construction"
	if ship != null and EconomyManager != null:
		display_type = EconomyManager.get_ship_display_type(ship.design_id)
	match display_type:
		"science":
			color = Color(0.4, 0.7, 1.0, 1.0)
		"construction":
			color = Color(0.95, 0.85, 0.3, 1.0)
		_:
			color = Color(0.95, 0.35, 0.3, 1.0)

	if _selected:
		var pulse_alpha: float = lerp(selection_pulse_min_alpha, selection_pulse_max_alpha,
			(sin(pulse_timer * selection_pulse_speed) + 1.0) / 2.0)
		var halo_color := Color(selection_halo_color.r, selection_halo_color.g, selection_halo_color.b, pulse_alpha)
		draw_circle(Vector2.ZERO, base_radius + selection_halo_radius_offset, halo_color)

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
