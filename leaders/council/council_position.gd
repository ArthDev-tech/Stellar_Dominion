class_name CouncilPosition
extends Resource
## One council seat definition: identity, base modifiers, unfilled penalty.

@export_group("Identity")
@export var position_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var required_class: int = 0  # LeaderClass.Class
@export var is_base_position: bool = true

@export_group("Empire-Wide Bonus (scales with assigned leader's level)")
@export var base_modifiers: Dictionary = {}

@export_group("Penalty if Unfilled")
@export var unfilled_penalty: Dictionary = {}

@export_group("Cascade Relevance")
@export_multiline var cascade_notes: String = ""
