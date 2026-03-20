class_name PolicyLever
extends Resource
## One policy lever (slider) for the political management screen.
## Value 0.0–1.0; slider values do not affect loyalty in phase 1.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Value")
@export var value: float = 0.5  ## 0.0–1.0
@export var dynamic_direction: bool = false  ## If true, effective direction/strength depend on value vs neutral (e.g. Tax Rate 25%)

@export_group("Labels")
@export var min_label: String = ""
@export var max_label: String = ""
@export var description: String = ""
