extends Node2D
## Decorative draw layer for system view (jump points, boundary, selection paths). No input.

var solar_view: Node = null


func _ready() -> void:
	z_index = -8
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if solar_view != null:
		solar_view._draw_system_view_overlay(self)
