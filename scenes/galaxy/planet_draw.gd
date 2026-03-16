extends Node2D
## Draws one planet in the solar system view.

const SIZE_SCALE := 2.0
const DEPOSIT_FONT_SIZE := 11
const DEPOSIT_OUTLINE_SIZE := 2
const COLLECTED_COLOR := Color(1.0, 0.65, 0.2, 1.0)

func _draw() -> void:
	var planet: Planet = get_meta("planet", null)
	if planet == null:
		return
	var size_scale: float = SIZE_SCALE
	if planet.type == Planet.PlanetType.GAS_GIANT:
		size_scale = SIZE_SCALE * 1.65  # Gas giants visibly larger
	var radius: float = (planet.size / 20.0) * size_scale
	radius = maxf(radius, 3.0)
	var color: Color = get_meta("color", Color.GRAY)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color.darkened(0.2), 1.0)
	_draw_deposits(planet, radius)

func _draw_deposits(planet: Planet, radius: float) -> void:
	if planet.deposits.is_empty():
		return
	var text: String = _format_deposits(planet.deposits)
	var font: Font = ThemeDB.fallback_font
	var pos: Vector2 = (Vector2(-40, -radius - 4)).floor()
	var text_color: Color = COLLECTED_COLOR if get_meta("is_being_collected", false) else Color.WHITE
	font.draw_string_outline(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, DEPOSIT_FONT_SIZE, DEPOSIT_OUTLINE_SIZE, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, DEPOSIT_FONT_SIZE, text_color)

func _format_deposits(deposits: Array) -> String:
	var parts: PackedStringArray = []
	for d in deposits:
		var rt: int = d.get("resource_type", 0)
		var amt: float = d.get("amount", 0.0)
		var short: String = GameResources.RESOURCE_SHORT_NAMES.get(rt, "?")
		if short.length() > 2:
			short = short.substr(0, 2)
		parts.append("%s %.0f" % [short, amt])
	return " ".join(parts)
