extends Control
## Draws an icon for a resource type: custom texture if set, else shape + color for the top bar.
## Set resource_type and icon_texture (optional) and call queue_redraw() when needed.

var resource_type: int = GameResources.ResourceType.ENERGY  ## Set from outside
var icon_texture: Texture2D = null  ## Set by ResourceStripController when ResourceIconSet provides a path

func _draw() -> void:
	if icon_texture != null:
		draw_texture_rect(icon_texture, Rect2(Vector2.ZERO, size), false)
		return
	var color: Color = GameResources.RESOURCE_ICON_COLORS.get(resource_type, Color.WHITE)
	var center := size / 2.0
	var r: float = minf(size.x, size.y) * 0.4
	# Shape by category: circle (basic), diamond (advanced), triangle (strategic/empire)
	if resource_type <= GameResources.ResourceType.FOOD:
		draw_circle(center, r, color)
	elif resource_type <= GameResources.ResourceType.CONSUMER_GOODS:
		# Diamond
		var pts: PackedVector2Array = [
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		]
		draw_colored_polygon(pts, color)
	elif resource_type <= GameResources.ResourceType.TRADE:
		# Triangle (empire)
		var pts: PackedVector2Array = [
			center + Vector2(0, -r),
			center + Vector2(r * 0.9, r * 0.9),
			center + Vector2(-r * 0.9, r * 0.9)
		]
		draw_colored_polygon(pts, color)
	else:
		# Strategic: square
		draw_rect(Rect2(center.x - r, center.y - r, r * 2.0, r * 2.0), color)
