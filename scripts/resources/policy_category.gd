class_name PolicyCategory
extends Resource
## One category panel (e.g. Military & Security) with a list of policy levers for the current government.

@export var id: StringName = &""
@export var display_name: String = ""
@export var policies: Array[PolicyLever] = []
