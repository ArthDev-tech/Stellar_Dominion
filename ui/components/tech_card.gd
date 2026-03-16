@tool
extends PanelContainer
## Single technology card for the tech tree. Edit this scene to change card layout and styling.
## In the editor, cards named "tech_*" under TreeCanvas load data from techs.json so names/descriptions/requirements show.

signal pressed(tech_def: Dictionary)

const BRANCH_COLORS: Dictionary = {
	"physical": Color(0.0, 0.78, 1.0),
	"social": Color(1.0, 0.77, 0.3),
	"xenological": Color(0.71, 0.3, 1.0),
}
## Outline color per tier (1–15). Used for card border so tier is visible in editor and game.
const TIER_COLORS: Array[Color] = [
	Color(0.45, 0.5, 0.6),    # 1 - slate
	Color(0.3, 0.55, 0.85),   # 2 - blue
	Color(0.2, 0.7, 0.5),     # 3 - green
	Color(0.75, 0.65, 0.25),  # 4 - gold
	Color(0.9, 0.5, 0.2),     # 5 - orange
	Color(0.85, 0.35, 0.4),   # 6 - red
	Color(0.6, 0.35, 0.85),   # 7 - purple
	Color(0.9, 0.4, 0.7),     # 8 - pink
	Color(0.25, 0.8, 0.9),    # 9 - cyan
	Color(0.95, 0.9, 0.5),    # 10 - bright gold
	Color(0.95, 0.95, 1.0),   # 11 - near white
	Color(1.0, 0.85, 0.4),    # 12 - legendary
	Color(0.5, 0.95, 0.6),    # 13 - mint
	Color(0.95, 0.6, 0.2),    # 14 - amber
	Color(0.85, 0.75, 1.0),   # 15 - lavender
]

## Override display text when set in the card scene; otherwise tech_def name_key/description are used.
@export var card_display_name: String = ""
@export var card_description: String = ""

@onready var _card_button: Button = $CardButton
@onready var _icon_rect: ColorRect = $CardButton/Content/IconRect
@onready var _title_label: Label = $CardButton/Content/VBox/TitleLabel
@onready var _desc_label: Label = $CardButton/Content/VBox/DescLabel
@onready var _cost_label: Label = $CardButton/Content/VBox/CostLabel
var _require_label: Label = null

var _tech_def: Dictionary = {}
var _branch_key: String = "physical"


func _ready() -> void:
	if _card_button != null:
		_card_button.pressed.connect(_on_button_pressed)
	if Engine.is_editor_hint():
		var tech_id: String = ""
		if name.begins_with("tech_"):
			tech_id = name
		elif scene_file_path != "":
			var fname: String = scene_file_path.get_file()
			if fname.get_extension() == "tscn":
				tech_id = fname.get_basename()
			if not tech_id.begins_with("tech_"):
				tech_id = ""
		if not tech_id.is_empty():
			_apply_tech_data_in_editor(tech_id)


## Fill the card from tech definition. state: "completed" | "in_progress" | "available" | "locked"
## Resolves label refs if @onready hasn't run yet (card not in tree when apply_tech_def is called).
func apply_tech_def(tech_def: Dictionary, branch_key: String, state: String) -> void:
	_tech_def = tech_def
	_branch_key = branch_key
	_resolve_label_refs()
	var name_key: String = card_display_name if not card_display_name.is_empty() else tech_def.get("name_key", "?")
	var cost: int = int(tech_def.get("cost", 0))
	var desc: String = card_description if not card_description.is_empty() else tech_def.get("description", "")
	if desc.is_empty():
		desc = "No description."
	var tier: int = int(tech_def.get("tier", 1))
	var tier_col: Color = TIER_COLORS[clampi(tier - 1, 0, TIER_COLORS.size() - 1)] if TIER_COLORS.size() > 0 else Color(0.5, 0.55, 0.65)
	var branch_col: Color = BRANCH_COLORS.get(branch_key, Color.WHITE)
	# Style panel: tier outline, branch accent on icon
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.2, 0.98)
	panel_style.border_color = tier_col
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 3
	panel_style.shadow_offset = Vector2(1, 2)
	add_theme_stylebox_override("panel", panel_style)
	# Icon (branch color)
	if _icon_rect != null:
		_icon_rect.color = branch_col.darkened(0.3)
	# Title
	if _title_label != null:
		if state == "completed":
			_title_label.text = "✓ " + name_key
			modulate = Color(0.7, 0.7, 0.75)
		elif state == "in_progress":
			_title_label.text = name_key + " (…)"
			_title_label.add_theme_color_override("font_color", branch_col)
		elif state == "available":
			_title_label.text = name_key
			_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		else:
			_title_label.text = name_key
			modulate = Color(0.5, 0.5, 0.55)
	if _desc_label != null:
		_desc_label.text = desc
	if _cost_label != null:
		_cost_label.text = "%d RP" % cost
	# Requirements line (prereq names at runtime when ResearchManager available, else ids)
	var require_text: String = ""
	var prereqs: Array = tech_def.get("prerequisites", [])
	if prereqs.is_empty():
		require_text = "Requires: None"
	else:
		var parts: PackedStringArray = []
		var rm = null
		if not Engine.is_editor_hint() and is_inside_tree():
			rm = get_node_or_null("/root/ResearchManager")
		for pid in prereqs:
			if rm != null and rm.has_method("get_tech_def"):
				var d: Dictionary = rm.get_tech_def(pid)
				parts.append(d.get("name_key", pid))
			else:
				parts.append(pid)
		require_text = "Requires: " + ", ".join(parts)
	if _require_label != null:
		_require_label.text = require_text
		_require_label.visible = true


func _resolve_label_refs() -> void:
	if _title_label == null:
		_title_label = get_node_or_null("CardButton/Content/VBox/TitleLabel") as Label
	if _desc_label == null:
		_desc_label = get_node_or_null("CardButton/Content/VBox/DescLabel") as Label
	if _cost_label == null:
		_cost_label = get_node_or_null("CardButton/Content/VBox/CostLabel") as Label
	if _require_label == null:
		_require_label = get_node_or_null("CardButton/Content/VBox/RequireLabel") as Label
	if _icon_rect == null:
		_icon_rect = get_node_or_null("CardButton/Content/IconRect") as ColorRect
	if _card_button == null:
		_card_button = get_node_or_null("CardButton") as Button


func _apply_tech_data_in_editor(tech_id: String = "") -> void:
	if tech_id.is_empty():
		tech_id = name
	var path := ProjectPaths.DATA_TECHS
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var techs: Array = json.data if json.data is Array else []
	var tech_def: Dictionary = {}
	for t in techs:
		if t.get("id", "") == tech_id:
			tech_def = t
			break
	if tech_def.is_empty():
		return
	var cat: int = int(tech_def.get("category", 0))
	var branch_key: String = ["physical", "social", "xenological"][clampi(cat, 0, 2)]
	apply_tech_def(tech_def, branch_key, "available")


func get_tech_def() -> Dictionary:
	return _tech_def


func _on_button_pressed() -> void:
	pressed.emit(_tech_def)
