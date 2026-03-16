class_name Anomaly
extends RefCounted
## An anomaly in a system; can be part of a precursor chain.

var id: int
var system_id: int
var precursor_id: String  ## Empty if not precursor-related
var surveyed_by_empire_id: int = -1  ## -1 = not yet surveyed


func _init(p_id: int = 0, p_system_id: int = 0, p_precursor_id: String = "") -> void:
	id = p_id
	system_id = p_system_id
	precursor_id = p_precursor_id


func is_surveyed() -> bool:
	return surveyed_by_empire_id >= 0
