class_name Hyperlane
extends RefCounted
## A connection between two star systems (FTL lane).

var from_id: int
var to_id: int


func _init(p_from_id: int, p_to_id: int) -> void:
	from_id = p_from_id
	to_id = p_to_id
