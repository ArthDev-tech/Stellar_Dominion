extends Area2D
## Draws a ship in the solar system view. Collision for click/overlap.
## Shape matches galaxy indicator_type: science=circle, construction=square, military=triangle.

const SIZE := 5.0
const COLLISION_RADIUS := 10.0

var _hull_color: Color = Color(0.9, 0.85, 0.5)
var _shape_key: String = "triangle"  ## "science" | "construction" | "military" (galaxy indicator_type)
var _selected: bool = false
var _pulse_timer: float = 0.0

@export_group("Selection Visual")
var selected: bool:
	get: return _selected
	set(v): _selected = v; queue_redraw()
@export var selection_halo_color: Color = Color(0.27, 0.67, 1.0, 0.6)
@export var selection_halo_radius_offset: float = 6.0
@export var selection_pulse_speed: float = 2.5
@export var selection_pulse_min_alpha: float = 0.3
@export var selection_pulse_max_alpha: float = 0.75


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	input_pickable = true
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_update_appearance_from_ship()


func _process(delta: float) -> void:
	if _selected:
		_pulse_timer += delta
		queue_redraw()


func _update_appearance_from_ship() -> void:
	var ship: Ship = get_meta("ship", null) as Ship
	if ship == null:
		return
	var def: Dictionary = {}
	if ShipDesignManager != null:
		def = ShipDesignManager.get_design(ship.design_id)
	# Hull color: from design, optionally tinted by empire
	var rgb: Array = def.get("hull_color", [0.9, 0.85, 0.5])
	_hull_color = Color(rgb[0] if rgb.size() > 0 else 0.9, rgb[1] if rgb.size() > 1 else 0.85, rgb[2] if rgb.size() > 2 else 0.5)
	if EmpireManager != null:
		var emp: Empire = EmpireManager.get_empire(ship.empire_id)
		if emp != null:
			_hull_color = _hull_color.lerp(emp.color, 0.35)
	# Shape from galaxy indicator_type (science=circle, construction=square, military=triangle)
	if EconomyManager != null:
		_shape_key = EconomyManager.get_ship_display_type(ship.design_id)
	else:
		_shape_key = "construction"


func _draw() -> void:
	var half := SIZE / 2.0
	var base_radius: float = SIZE
	if _selected:
		var pulse_alpha: float = lerp(selection_pulse_min_alpha, selection_pulse_max_alpha,
			(sin(_pulse_timer * selection_pulse_speed) + 1.0) / 2.0)
		var halo_color := Color(selection_halo_color.r, selection_halo_color.g, selection_halo_color.b, pulse_alpha)
		draw_circle(Vector2.ZERO, base_radius + selection_halo_radius_offset, halo_color)
	# Shape matches galaxy indicators: science=circle, construction=square, military=triangle
	match _shape_key:
		"science":
			draw_circle(Vector2.ZERO, half, _hull_color)
			draw_arc(Vector2.ZERO, half, 0.0, TAU, 24, _hull_color.darkened(0.3), 1.0)
		"construction":
			var rect: Rect2 = Rect2(-half, -half, SIZE, SIZE)
			draw_rect(rect, _hull_color)
			draw_rect(rect, _hull_color.darkened(0.3), false)
		"military":
			var tri: PackedVector2Array = [
				Vector2(0.0, -half),
				Vector2(-half, half),
				Vector2(half, half)
			]
			draw_colored_polygon(tri, _hull_color)
			tri.append(tri[0])
			draw_polyline(tri, _hull_color.darkened(0.3))
		_:
			# Fallback: military-style triangle
			var tri: PackedVector2Array = [
				Vector2(0.0, -half),
				Vector2(-half, half),
				Vector2(half, half)
			]
			draw_colored_polygon(tri, _hull_color)
			tri.append(tri[0])
			draw_polyline(tri, _hull_color.darkened(0.3))
