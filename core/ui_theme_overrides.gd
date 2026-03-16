class_name UIThemeOverrides
extends Resource
## Optional theme overrides for resource strip, selected panel, and research panel.
## Assign in inspector or leave null to use built-in defaults.

@export_group("Resource strip")
@export var strip_panel_bg_color: Color = Color(0.14, 0.16, 0.22, 0.92)
@export var strip_panel_bg_raw: Color = Color(0.12, 0.2, 0.16, 0.92)
@export var strip_panel_bg_refined: Color = Color(0.12, 0.16, 0.22, 0.92)
@export var strip_panel_bg_strategic: Color = Color(0.18, 0.14, 0.24, 0.92)
@export var strip_panel_bg_abstract: Color = Color(0.22, 0.18, 0.12, 0.92)
@export var strip_panel_border_color: Color = Color(0.3, 0.4, 0.55, 0.9)
@export var strip_panel_border_width: int = 1
@export var strip_panel_corner_radius: int = 3
@export var strip_panel_content_margin: int = 10
@export var strip_header_font_size: int = 14
@export var strip_header_font_color: Color = Color(0.35, 0.55, 0.72, 1.0)
@export var strip_value_font_size: int = 20
@export var strip_value_font_color: Color = Color(0.78, 0.91, 1.0, 1.0)
@export var strip_value_font_color_positive: Color = Color(1.0, 0.65, 0.2, 1.0)
@export var strip_separation: int = 8
@export var strip_icon_size: int = 27

@export_group("Selected panel / info panel")
@export var panel_label_font_size_small: int = 11
@export var panel_label_font_size_medium: int = 12
@export var panel_label_font_size_large: int = 13
@export var panel_label_color_primary: Color = Color(0.9, 0.92, 1.0)
@export var panel_label_color_secondary: Color = Color(0.85, 0.88, 0.95)
@export var panel_label_color_tertiary: Color = Color(0.7, 0.78, 0.9)
@export var panel_label_color_muted: Color = Color(0.8, 0.85, 0.95)
@export var panel_vbox_separation: int = 4
@export var panel_hbox_separation: int = 6

@export_group("Top bar")
@export var bar_bg_color: Color = Color(0.02, 0.04, 0.07, 0.97)
@export var bar_border_color: Color = Color(0.12, 0.23, 0.37, 1.0)
@export var bar_height: float = 36.0
@export var bar_date_font_size: int = 18
@export var resource_value_color: Color = Color(0.78, 0.91, 1.0, 1.0)
@export var resource_label_color: Color = Color(0.35, 0.55, 0.72, 1.0)

@export_group("Sidebar")
@export var sidebar_bg_color: Color = Color(0.02, 0.03, 0.06, 0.97)
@export var sidebar_width: float = 52.0
@export var item_text_color: Color = Color(0.25, 0.48, 0.65, 1.0)
@export var item_hover_color: Color = Color(0.45, 0.68, 0.88, 1.0)
@export var item_active_color: Color = Color(0.78, 0.91, 1.0, 1.0)
@export var item_active_accent: Color = Color(0.29, 0.55, 0.77, 1.0)
