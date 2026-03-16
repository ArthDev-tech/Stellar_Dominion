extends Node2D
## Draws the star (or black hole / pulsar / neutron star) at center of the solar system view.

const DEFAULT_RADIUS := 68.0
const DEPOSIT_FONT_SIZE := 11
const DEPOSIT_OUTLINE_SIZE := 2
const COLLECTED_COLOR := Color(1.0, 0.65, 0.2, 1.0)

# StarSystem.StarType enum values for special stars
const TYPE_BLACK_HOLE := 7
const TYPE_PULSAR := 8
const TYPE_NEUTRON_STAR := 9

func _draw() -> void:
	var star_type: int = get_meta("star_type", 2)  # G = 2
	var color: Color = get_meta("color", Color.WHITE)
	var radius: float = get_meta("radius", DEFAULT_RADIUS)

	if star_type == TYPE_BLACK_HOLE:
		# Dark center with accretion disk
		draw_circle(Vector2.ZERO, radius * 0.4, Color(0.05, 0.02, 0.02, 1))
		draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 64, Color(0.4, 0.25, 0.5, 0.9), radius * 0.35)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.2, 0.15, 0.35, 0.6), radius * 0.2)
		_draw_deposits(radius)
		return
	elif star_type == TYPE_PULSAR:
		# Bright, sharp white with pulse-like rings
		draw_circle(Vector2.ZERO, radius, Color(0.95, 0.98, 1.0, 1))
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 32, Color(0.8, 0.85, 1.0, 0.5), 4.0)
		draw_arc(Vector2.ZERO, radius + 18.0, 0.0, TAU, 32, Color(0.6, 0.7, 1.0, 0.25), 2.0)
		_draw_deposits(radius)
		return
	elif star_type == TYPE_NEUTRON_STAR:
		# Small, very bright
		var r: float = radius * 0.35
		draw_circle(Vector2.ZERO, r, Color(0.98, 0.99, 1.0, 1))
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(0.85, 0.9, 1.0, 0.6), 2.0)
		_draw_deposits(radius * 0.35 + 8)
		return
	else:
		# Normal star
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.4), 3.0)
	_draw_deposits(radius)

func _draw_deposits(radius: float) -> void:
	var deposits: Array = get_meta("star_deposits", [])
	if deposits.is_empty():
		return
	var text: String = _format_deposits(deposits)
	var font: Font = ThemeDB.fallback_font
	var pos: Vector2 = (Vector2(-80, radius + 10)).floor()
	var text_color: Color = COLLECTED_COLOR if get_meta("is_being_collected", false) else Color.WHITE
	font.draw_string_outline(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160, DEPOSIT_FONT_SIZE, DEPOSIT_OUTLINE_SIZE, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160, DEPOSIT_FONT_SIZE, text_color)

func _format_deposits(deposits: Array) -> String:
	var parts: PackedStringArray = []
	for d in deposits:
		var rt: int = d.get("resource_type", 0)
		var amt: float = d.get("amount", 0.0)
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		if short.length() > 2:
			short = short.substr(0, 2)
		parts.append("%s %.0f" % [short, amt])
	return "  ".join(parts)
