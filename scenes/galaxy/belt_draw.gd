extends Node2D
## Draws one asteroid belt as a ring in the solar system view.

const DEPOSIT_FONT_SIZE := 11
const DEPOSIT_OUTLINE_SIZE := 2
const COLLECTED_COLOR := Color(1.0, 0.65, 0.2, 1.0)

func _draw() -> void:
	var inner_r: float = get_meta("inner_radius", 100.0)
	var outer_r: float = get_meta("outer_radius", 130.0)
	var color: Color = Color(0.55, 0.5, 0.45, 0.6)
	# Draw ring as thick outline
	var mid_r: float = (inner_r + outer_r) * 0.5
	draw_arc(Vector2.ZERO, mid_r, 0.0, TAU, 96, color, (outer_r - inner_r) * 0.5)
	var belt: AsteroidBelt = get_meta("belt", null)
	if belt != null and belt.deposits.size() > 0:
		var text: String = _format_deposits(belt.deposits)
		var font: Font = ThemeDB.fallback_font
		var pos: Vector2 = (Vector2(mid_r + 8, 4)).floor()
		var text_color: Color = COLLECTED_COLOR if get_meta("is_being_collected", false) else Color.WHITE
		font.draw_string_outline(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, 90, DEPOSIT_FONT_SIZE, DEPOSIT_OUTLINE_SIZE, Color.BLACK)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, 90, DEPOSIT_FONT_SIZE, text_color)

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
