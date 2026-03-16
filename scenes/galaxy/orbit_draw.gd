extends Node2D
## Draws one orbit circle in the solar system view.

func _draw() -> void:
	var radius: float = get_meta("radius", 100.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.4, 0.45, 0.55, 0.5), 1.5)
