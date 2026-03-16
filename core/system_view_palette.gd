class_name SystemViewPalette
extends Resource
## Optional palette for system view: star colors, planet colors, and click radii.
## Assign on SolarSystemView to tune in the inspector; leave null to use built-in defaults.

@export_group("Click radii")
@export var station_click_radius: float = 14.0
@export var ship_click_radius: float = 12.0

@export_group("Star colors")
## Order: M, K, G, F, A, B, O, BLACK_HOLE, PULSAR, NEUTRON_STAR. Leave empty for defaults.
@export var star_colors: Array[Color] = []

@export_group("Planet colors")
## Order: BARREN, DESERT, ARCTIC, TROPICAL, CONTINENTAL, OCEAN, GAIA, GAS_GIANT, LAVA, HOTHOUSE. Leave empty for defaults.
@export var planet_colors: Array[Color] = []


func get_star_color(index: int) -> Color:
	if index >= 0 and index < star_colors.size():
		return star_colors[index]
	return _default_star_color(index)


func get_planet_color(index: int) -> Color:
	if index >= 0 and index < planet_colors.size():
		return planet_colors[index]
	return _default_planet_color(index)


func _default_star_color(index: int) -> Color:
	var defaults: Array[Color] = [
		Color(0.9, 0.4, 0.2),   # M
		Color(0.95, 0.6, 0.2),  # K
		Color(1.0, 0.95, 0.6),  # G
		Color(1.0, 1.0, 0.9),   # F
		Color(0.95, 0.98, 1.0), # A
		Color(0.7, 0.8, 1.0),   # B
		Color(0.4, 0.5, 1.0),   # O
		Color(0.1, 0.05, 0.1),  # BLACK_HOLE
		Color(0.95, 0.98, 1.0), # PULSAR
		Color(0.98, 0.99, 1.0), # NEUTRON_STAR
	]
	if index >= 0 and index < defaults.size():
		return defaults[index]
	return Color.WHITE


func _default_planet_color(index: int) -> Color:
	var defaults: Array[Color] = [
		Color(0.5, 0.45, 0.4),   # BARREN
		Color(0.85, 0.7, 0.35),  # DESERT
		Color(0.7, 0.85, 1.0),   # ARCTIC
		Color(0.3, 0.7, 0.35),   # TROPICAL
		Color(0.35, 0.6, 0.4),   # CONTINENTAL
		Color(0.2, 0.4, 0.8),    # OCEAN
		Color(0.4, 0.85, 0.5),   # GAIA
		Color(0.9, 0.75, 0.45),  # GAS_GIANT
		Color(0.9, 0.35, 0.15),  # LAVA
		Color(0.95, 0.8, 0.4),   # HOTHOUSE
	]
	if index >= 0 and index < defaults.size():
		return defaults[index]
	return Color.GRAY
