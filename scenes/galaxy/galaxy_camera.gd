extends Camera2D
## Galaxy map camera. Zoom limits and step are exposed for inspector tuning.

@export_group("Zoom")
@export var zoom_min: float = 0.12
@export var zoom_max: float = 9.0
@export var zoom_step: float = 0.1
@export var zoom_smoothing: float = 8.0
