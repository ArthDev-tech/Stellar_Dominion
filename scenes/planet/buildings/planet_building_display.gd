extends Control
## Displays one planet building definition: icon and reference to the .tres for editing.
## Assign definition in the Inspector to the corresponding resource in data/planet_buildings/.

@export var definition: PlanetBuildingDefinitionResource

@onready var _icon_rect: TextureRect = $TextureRect


func _ready() -> void:
	_refresh_icon()


func _refresh_icon() -> void:
	if _icon_rect == null:
		return
	if definition != null and definition.icon_path != "" and ResourceLoader.exists(definition.icon_path):
		var tex: Texture2D = load(definition.icon_path) as Texture2D
		if tex != null:
			_icon_rect.texture = tex
			_icon_rect.visible = true
			return
	_icon_rect.visible = definition != null and definition.icon_path != ""
