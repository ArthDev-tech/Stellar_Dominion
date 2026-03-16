class_name FallenEmpire
extends RefCounted
## A fallen empire: fixed territory, high power, does not expand.

var id: int
var name_key: String
var system_ids: Array[int] = []
var fleet_power: int = 50000
var is_awakened: bool = false


func _init(p_id: int = 0, p_name_key: String = "") -> void:
	id = p_id
	name_key = p_name_key


func owns_system(system_id: int) -> bool:
	return system_id in system_ids
