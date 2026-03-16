extends Node2D
## Draws a space station in the solar system view (small diamond/station icon at planet orbit).

const SIZE := 8.0

func _draw() -> void:
	# Simple station shape: small rotated square / diamond
	var half := SIZE / 2.0
	var color: Color = Color(0.4, 0.85, 1.0)  # Cyan-ish
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -half),
		Vector2(half, 0),
		Vector2(0, half),
		Vector2(-half, 0)
	]), color)
	draw_polyline(PackedVector2Array([
		Vector2(0, -half),
		Vector2(half, 0),
		Vector2(0, half),
		Vector2(-half, 0),
		Vector2(0, -half)
	]), color.darkened(0.3))
