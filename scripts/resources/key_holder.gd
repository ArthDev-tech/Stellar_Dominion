class_name KeyHolder
extends Resource
## One key holder (voting bloc / power faction) with loyalty and an active demand.
## Inspector-editable for balance tuning.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var faction_type: String = ""
@export var description: String = ""

@export_group("Loyalty")
@export var loyalty: float = 50.0  ## 0–100

@export_group("Demand")
@export var demand_resource: String = ""
@export var demand_amount: int = 0
@export var demand_fulfilled: bool = false
