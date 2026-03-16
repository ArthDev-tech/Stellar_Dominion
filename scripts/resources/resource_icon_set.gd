class_name ResourceIconSet
extends Resource
## Optional per-resource icon paths for the top bar. Index = GameResources.ResourceType.
## Empty string = use fallback colored shape. Assign on GameplayConfig.

@export var base_path: String = "res://assets/icons/resources/"
## Icon paths by ResourceType index. Non-empty path loads texture; empty = shape.
@export var icon_paths: Array[String] = []
