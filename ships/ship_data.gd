class_name ShipData
extends Resource
## Per-ship display/summary data for fleet composition and fleet panel.

@export var ship_name: String = ""
@export var ship_class: String = ""  # "corvette" | "destroyer" | "cruiser" | "battleship" | "titan" | "science" | "constructor" | "transport"
@export var combat_power: float = 0.0
@export var hull_current: float = 100.0
@export var hull_max: float = 100.0
