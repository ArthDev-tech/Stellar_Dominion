class_name GameplayConfig
extends Resource
## Tuning for time scale, camera zoom/pan, galaxy/system view, overlays, and UI.
## Assign in the inspector on GameScene and SolarSystemView, or use a shared .tres.

@export_group("Time")
@export var seconds_per_month: float = 2.0
@export var seconds_per_day: float = -1.0  ## If < 0, derived as seconds_per_month / 30.0

@export_group("Galaxy quick-start")
## Used when starting game without galaxy setup (e.g. running game_scene directly).
@export var galaxy_system_count: int = 50
@export var galaxy_seed: int = -1
@export var galaxy_num_ai_empires: int = 2

@export_group("Galaxy map")
@export var system_radius: float = 12.0
@export var click_max_distance: float = 25.0
@export var star_radius_for_indicators: float = 8.0
@export var indicator_y_offset: float = 14.0
@export var indicator_size: float = 3.0
@export var indicator_dx: float = 8.0
@export var zoom_speed: float = 1.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.0
@export var pan_speed: float = 400.0

@export_group("Galaxy map visuals")
@export var hyperline_width: float = 1.5
@export var hyperline_color: Color = Color(0.35, 0.4, 0.6, 0.8)
## Max galaxy-world offset from destination star toward origin along the lane (actual offset is min of this and lane_fraction * lane_length).
@export var jump_point_radius_galaxy: float = 400.0
## Jump point distance along hyperlane = min(radius_galaxy, lane_length * this). Keep ~0.15–0.25.
@export var jump_point_lane_fraction: float = 0.2
## Unused (ships remain at jump point after hyperlane). Kept for saved scenes / future use.
@export var ingress_days: int = 14
@export var route_preview_z_index: int = 10
@export var route_preview_width: float = 3.0
@export var route_preview_color: Color = Color(1.0, 0.85, 0.2, 0.95)

@export_group("UI behavior")
@export var galaxy_click_drag_threshold: float = 5.0
@export var hover_delay_seconds: float = 0.35
@export var indicator_redraw_interval: float = 1.0

@export_group("Overlay layout")
## Dimmer behind overlays (RGBA).
@export var overlay_dimmer_color: Color = Color(0, 0, 0, 0.55)
## Offsets from center: x=left, y=top, z=right, w=bottom.
@export var overlay_colonies_rect: Vector4 = Vector4(-280, -220, 280, 220)
@export var overlay_technology_rect: Vector4 = Vector4(-320, -240, 320, 240)
@export var overlay_leaders_rect: Vector4 = Vector4(-260, -200, 260, 200)
@export var overlay_government_rect: Vector4 = Vector4(-320, -280, 320, 280)
@export var overlay_planet_view_rect: Vector4 = Vector4(-675, -540, 675, 540)
@export var overlay_station_rect: Vector4 = Vector4(-450, -350, 450, 350)
@export var overlay_ship_designer_rect: Vector4 = Vector4(-470, -310, 470, 310)

@export_group("Theme")
## Optional. If null, built-in colors and font sizes are used for resource strip and panels.
@export var ui_theme: UIThemeOverrides = null
## Optional. If set, resource strip uses these icon textures instead of colored shapes.
@export var resource_icon_set: ResourceIconSet = null

@export_group("System view")
@export var star_radius: float = 68.0
@export var planet_size_scale: float = 2.0
@export var star_click_radius: float = 55.0
@export var planet_click_radius: float = 18.0
@export var system_zoom_speed: float = 1.15
@export var system_min_zoom: float = 0.4
@export var system_max_zoom: float = 4.0
@export var click_drag_threshold: float = 6.0


func get_seconds_per_day() -> float:
	if seconds_per_day >= 0.0:
		return seconds_per_day
	return seconds_per_month / 30.0
